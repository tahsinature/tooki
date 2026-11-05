import AppKit
import TookiKit

/// Shows and places the shelf, and runs shelf commands from hotkeys and `tooki://` links.
@MainActor
final class ShelfPanelController {
    let shelf: Shelf
    private lazy var panel = makePanel()
    private var hasBeenPlaced = false
    private(set) var isEnabled = true

    init(shelf: Shelf) {
        self.shelf = shelf
        shelf.onEmptied = { [weak self] in self?.hide() }
    }

    func apply(_ config: ShelfConfig) {
        isEnabled = config.enabled
        shelf.removeAfterDragOut = config.removeAfterDragOut
        if !isEnabled { hide() }
    }

    var isVisible: Bool { hasBeenPlaced && panel.isVisible }

    /// - Parameter focus: Takes keyboard focus so ⌘V, Delete and Esc work right away.
    func show(nearCursor: Bool = false, focus: Bool = false) {
        if nearCursor {
            placeNearCursor()
        } else if !hasBeenPlaced {
            placeInCorner()
        }
        hasBeenPlaced = true
        if focus {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        guard hasBeenPlaced else { return }
        panel.orderOut(nil)
    }

    func toggle() {
        guard isEnabled else { return NSSound.beep() }
        isVisible ? hide() : show(focus: true)
    }

    func clearAndHide() {
        shelf.clear()
        hide()
    }

    func handle(_ command: ShelfCommand) {
        guard isEnabled else { return NSSound.beep() }
        switch command {
        case .add(let paths, let asCopies):
            let urls = paths
                .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !urls.isEmpty else {
                NSSound.beep()
                return
            }
            shelf.add(fileURLs: urls, mode: asCopies ? .copy : .original)
            show()
        case .show: show()
        case .hide: hide()
        case .toggle: toggle()
        case .clear: clearAndHide()
        }
    }

    /// Shows the shelf near the pointer while something is Shift-dragged, unless it's already up.
    func showForDrag() {
        if isEnabled, !isVisible { show(nearCursor: true) }
    }

    /// An empty shelf only appeared to catch the drag. The drop arrives just after the mouse
    /// goes up, so wait a moment before deciding.
    func dragEnded() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if shelf.isEmpty { hide() }
        }
    }

    private func makePanel() -> ShelfPanel {
        let view = ShelfView(
            shelf: shelf,
            onClose: { [weak self] in self?.clearAndHide() },
            onSizeChange: { [weak self] size in self?.fit(to: size) }
        )
        let panel = ShelfPanel(shelf: shelf, content: view)
        panel.onEscape = { [weak self] in self?.hide() }
        panel.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        return panel
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers?.lowercased()
        if event.modifierFlags.contains(.command) {
            switch key {
            case "v":
                if !shelf.add(from: .general) { NSSound.beep() }
            case "a":
                shelf.selection = Set(shelf.items.map(\.id))
            default:
                return false
            }
            return true
        }
        let deleteKeys: Set<UInt16> = [51, 117] // Delete and Forward Delete
        guard deleteKeys.contains(event.keyCode), !shelf.selection.isEmpty else { return false }
        shelf.remove(shelf.selection)
        return true
    }

    /// Keeps the top-left corner in place as the content grows or shrinks.
    private func fit(to size: CGSize) {
        var frame = panel.frame
        guard frame.size != size else { return }
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(onScreen(frame), display: true)
    }

    private func placeNearCursor() {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = CGPoint(x: mouse.x + 60, y: mouse.y - size.height / 2)
        if let screen = screen(containing: mouse), origin.x + size.width > screen.visibleFrame.maxX {
            origin.x = mouse.x - 60 - size.width
        }
        panel.setFrame(onScreen(CGRect(origin: origin, size: size)), display: false)
    }

    private func placeInCorner() {
        guard let visible = screen(containing: NSEvent.mouseLocation)?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = CGPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }

    private func onScreen(_ frame: CGRect) -> CGRect {
        guard let visible = screen(containing: CGPoint(x: frame.midX, y: frame.midY))?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        else { return frame }
        var frame = frame
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        return frame
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}
