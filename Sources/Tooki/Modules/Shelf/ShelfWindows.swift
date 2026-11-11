import AppKit
import TookiKit

/// One floating panel per shelf. Decides which shelves are shown, makes new ones and closes
/// them, and runs shelf commands from hotkeys, the menu and `tooki://` links.
@MainActor
final class ShelfWindows {
    let library: ShelfLibrary
    private(set) var isEnabled = true
    private var config = ShelfConfig()
    private var controllers: [Shelf.ID: ShelfPanelController] = [:]
    /// The empty shelf that appeared for a Shift-drag. It goes away if nothing is dropped on it.
    private var dragShelfID: Shelf.ID?

    init(library: ShelfLibrary) {
        self.library = library
    }

    /// Brings back the saved shelves.
    func start() {
        library.load()
        if isEnabled { showAll() }
    }

    func apply(_ config: ShelfConfig) {
        self.config = config
        isEnabled = config.enabled
        library.shelves.forEach { $0.removeAfterDragOut = config.removeAfterDragOut }
        if !isEnabled { hideAll() }
    }

    var isAnyVisible: Bool { controllers.values.contains(where: \.isVisible) }

    func isVisible(_ shelf: Shelf) -> Bool { controllers[shelf.id]?.isVisible == true }

    /// Hides every shelf if any is showing; otherwise shows them all, or a new one if there are none.
    func toggleAll() {
        guard isEnabled else { return NSSound.beep() }
        if isAnyVisible {
            hideAll()
        } else if library.isEmpty {
            newShelf()
        } else {
            showAll()
        }
    }

    func showAll() {
        guard isEnabled else { return NSSound.beep() }
        library.shelves.forEach { show($0) }
    }

    func hideAll() {
        library.shelves.forEach(hide)
    }

    /// Makes an empty shelf and shows it, by default with keyboard focus, ready for a drop or ⌘V.
    @discardableResult
    func newShelf(named name: String? = nil, focus: Bool = true) -> Shelf {
        let shelf = library.newShelf(named: name)
        show(shelf, focus: focus)
        return shelf
    }

    func show(_ shelf: Shelf, focus: Bool = false) {
        guard isEnabled else { return NSSound.beep() }
        let neighbour = library.shelves.lazy
            .filter { $0.id != shelf.id }
            .compactMap { self.controllers[$0.id]?.frame }
            .last
        controller(for: shelf).show(besides: neighbour, focus: focus)
    }

    func hide(_ shelf: Shelf) {
        controllers[shelf.id]?.hide()
    }

    /// Clears the shelf and closes it for good, once it has finished going away.
    func close(_ shelf: Shelf) {
        guard let controller = controllers.removeValue(forKey: shelf.id) else { return library.remove(shelf) }
        controller.hide(.closing) { [library] in library.remove(shelf) }
    }

    func closeAll() {
        library.shelves.forEach(close)
    }

    /// Asks first, since this throws away Tooki's copies on every shelf.
    func confirmCloseAll() {
        guard !library.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Clear all shelves?"
        alert.informativeText = """
        This closes \(ShelfText.shelfCount(library.shelves.count).lowercased()) with \
        \(ShelfText.itemCount(library.itemCount).lowercased()). Originals stay where they are; \
        Tooki's copies are deleted.
        """
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { closeAll() }
    }

    /// Tooki's copies are gone for good once removed, so the first request on a shelf that has
    /// any only arms the button; asking again does it. Shelves holding only originals act at once.
    private func request(_ action: ShelfAction, on shelf: Shelf) {
        guard !shelf.hasCopies || shelf.armed == action else { return shelf.arm(action) }
        shelf.disarm()
        switch action {
        case .clear: shelf.clear()
        case .delete: close(shelf)
        }
    }

    func handle(_ command: ShelfCommand) {
        guard isEnabled else { return NSSound.beep() }
        switch command {
        case .add(let paths, let asCopies, let reference):
            let urls = paths
                .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !urls.isEmpty else { return NSSound.beep() }
            let shelf = shelfToAdd(to: reference)
            shelf.add(fileURLs: urls, mode: asCopies ? .copy : .original)
            show(shelf)
        case .new:
            newShelf()
        case .show(let reference):
            forEachShelf(reference) { show($0) }
        case .hide(let reference):
            forEachShelf(reference, hide)
        case .toggle(let reference):
            guard let reference else { return toggleAll() }
            forEachShelf(reference) { isVisible($0) ? hide($0) : show($0) }
        case .clear(let reference):
            forEachShelf(reference, close)
        }
    }

    /// Adds what `pasteboard` holds without showing or hiding the shelf, so a hidden shelf stays
    /// hidden. A new shelf starts hidden too. Beeps when there was nothing usable.
    func add(from pasteboard: NSPasteboard, mode: ShelfAddMode, to destination: ShelfDestination) {
        guard isEnabled else { return NSSound.beep() }
        let shelf: Shelf
        switch destination {
        case .existing(let id):
            guard let existing = library.shelves.first(where: { $0.id == id }) else { return NSSound.beep() }
            shelf = existing
        case .new:
            shelf = library.newShelf()
        }
        // Wires up closing and settings like any other shelf.
        _ = controller(for: shelf)
        guard shelf.add(from: pasteboard, mode: mode) else {
            if shelf.isEmpty { close(shelf) }
            return NSSound.beep()
        }
    }

    /// Shows an empty shelf next to the pointer while something is Shift-dragged.
    func showForDrag() {
        guard isEnabled, dragShelfID == nil else { return }
        let shelf = library.newShelf()
        dragShelfID = shelf.id
        controller(for: shelf).show(nearCursor: true)
    }

    /// The drop arrives just after the mouse goes up, so wait a moment before deciding.
    func dragEnded() {
        guard let id = dragShelfID else { return }
        dragShelfID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if let shelf = library.shelves.first(where: { $0.id == id }), shelf.isEmpty { close(shelf) }
        }
    }

    /// No reference means the most recently used shelf. A name that's not taken yet makes a new shelf.
    private func shelfToAdd(to reference: String?) -> Shelf {
        guard let reference else { return library.mostRecent ?? library.newShelf() }
        if reference == ShelfCommand.newShelf { return library.newShelf() }
        return library.shelf(matching: reference) ?? library.newShelf(named: reference)
    }

    /// No reference means every shelf. An unknown one beeps.
    private func forEachShelf(_ reference: String?, _ body: (Shelf) -> Void) {
        guard let reference else { return library.shelves.forEach(body) }
        guard let shelf = library.shelf(matching: reference) else { return NSSound.beep() }
        body(shelf)
    }

    private func controller(for shelf: Shelf) -> ShelfPanelController {
        if let existing = controllers[shelf.id] { return existing }
        let controller = ShelfPanelController(shelf: shelf)
        shelf.removeAfterDragOut = config.removeAfterDragOut
        controller.onHide = { [weak self, weak shelf, weak controller] in
            guard let self, let shelf else { return }
            let frame = controller?.frame
            self.hide(shelf)
            if let frame { ShelfHiddenHUD.show(where: frame) }
        }
        controller.onNewShelf = { [weak self] in self?.newShelf() }
        controller.onDelete = { [weak self, weak shelf] in
            if let shelf { self?.request(.delete, on: shelf) }
        }
        controller.onClear = { [weak self, weak shelf] in
            if let shelf { self?.request(.clear, on: shelf) }
        }
        controllers[shelf.id] = controller
        return controller
    }
}
