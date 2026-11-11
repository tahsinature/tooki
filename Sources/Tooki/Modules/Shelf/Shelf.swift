import AppKit
import Observation

/// One shelf: its items, and which are selected. `ShelfLibrary` keeps every shelf and saves them.
@MainActor
@Observable
final class Shelf: Identifiable {
    let id: UUID
    private(set) var name: String
    /// When something was last added. Links and scripts add to the most recently used shelf.
    private(set) var lastUsed: Date
    private(set) var items: [ShelfItem]
    var selection: Set<ShelfItem.ID> = []
    var isExpanded = false {
        didSet { if !isExpanded { isShowingDetail = false } }
    }
    /// The list has slid over to the details of the item at the cursor.
    var isShowingDetail = false
    /// The shelf's panel has keyboard focus.
    var isFocused = false
    /// Esc is being held down; the shelf is deleted if it's held long enough.
    var isHoldingToDelete = false
    /// The shelf is on its way off screen.
    var leaving: ShelfLeaving?
    /// Clear or Delete was asked for and is waiting for a second click, since it deletes copies.
    private(set) var armed: ShelfAction?
    @ObservationIgnored private var disarming: Task<Void, Never>?
    /// Something is being dragged over the shelf.
    var dropTarget: ShelfDropTarget?
    /// Copies still being made. They show as "Copying…" and can't be dragged out yet.
    private(set) var copyingIDs: Set<ShelfItem.ID> = []
    @ObservationIgnored var removeAfterDragOut = true
    /// The item the arrow keys move from: the last one clicked or reached with an arrow.
    private(set) var cursor: ShelfItem.ID?

    /// Opens Quick Look for these files. Set by the shelf's panel, which owns the preview.
    @ObservationIgnored var onQuickLook: ([URL]) -> Void = { _ in }
    /// Runs whenever something worth saving changed.
    @ObservationIgnored var onChange: () -> Void = {}

    init(name: String) {
        id = UUID()
        self.name = name
        lastUsed = Date()
        items = []
    }

    /// Files that were moved or deleted while Tooki wasn't running are left out.
    init(saved: SavedShelf) {
        id = saved.id
        name = saved.name
        lastUsed = saved.lastUsed
        items = saved.items.filter(\.exists)
    }

    var isEmpty: Bool { items.isEmpty }
    var selectedItems: [ShelfItem] { items.filter { selection.contains($0.id) } }
    var totalBytes: Int64 { items.compactMap(\.byteSize).reduce(0, +) }
    /// Tooki's copies are deleted along with the shelf, so removing them is worth a question.
    var hasCopies: Bool { items.contains(where: \.isCopy) }

    /// Waits a few seconds for the action to be confirmed, then lets it go.
    func arm(_ action: ShelfAction) {
        armed = action
        disarming?.cancel()
        disarming = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.disarm()
        }
    }

    func disarm() {
        disarming?.cancel()
        disarming = nil
        armed = nil
    }
    /// The item whose details are showing, if any.
    var detailItem: ShelfItem? {
        guard isExpanded, isShowingDetail else { return nil }
        return cursorItem
    }
    var cursorItem: ShelfItem? { items.first { $0.id == cursor } }
    /// Files that are ready to be used: copies still being made are left out.
    var readyURLs: [URL] {
        items.filter { !copyingIDs.contains($0.id) }.map(\.url)
    }

    /// Copies still being made aren't saved; if Tooki quits mid-copy they're simply gone.
    var saved: SavedShelf {
        SavedShelf(id: id, name: name, lastUsed: lastUsed, items: items.filter { !copyingIDs.contains($0.id) })
    }

    func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != name else { return }
        name = trimmed
        save()
    }

    /// Renames the item's file on disk: the real file for an original, Tooki's file for a copy.
    func rename(_ item: ShelfItem, to newName: String) throws {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), name != item.url.lastPathComponent,
              let index = items.firstIndex(where: { $0.id == item.id })
        else { return }
        let destination = item.url.deletingLastPathComponent().appending(path: name)
        try FileManager.default.moveItem(at: item.url, to: destination)
        items[index].relocate(to: destination)
        save()
    }

    /// The items a right-click acts on: the selection if the clicked item is in it, otherwise
    /// just that item, which becomes the selection, like Finder.
    func itemsForMenu(clickedOn item: ShelfItem) -> [ShelfItem] {
        if selection.contains(item.id) { return selectedItems }
        selection = [item.id]
        return [item]
    }

    /// Adds files or folders, either as links to the originals or as Tooki's own copies.
    /// An original and a copy of the same file can sit side by side; two of the same kind can't.
    func add(fileURLs: [URL], mode: ShelfAddMode) {
        switch mode {
        case .original: add(fileURLs.map(ShelfItem.init(fileURL:)))
        case .copy: fileURLs.forEach(addCopy)
        }
    }

    func add(_ newItems: [ShelfItem]) {
        let known = Set(items.map(\.dedupeKey))
        let fresh = newItems.filter { !known.contains($0.dedupeKey) }
        guard !fresh.isEmpty else { return }
        items += fresh
        lastUsed = Date()
        save()
    }

    /// Adds whatever the pasteboard holds. Returns `false` when there was nothing usable.
    @discardableResult
    func add(from pasteboard: NSPasteboard, mode: ShelfAddMode = .original) -> Bool {
        let fileURLs = ShelfContentReader.fileURLs(from: pasteboard)
        if !fileURLs.isEmpty {
            add(fileURLs: fileURLs, mode: mode)
            return true
        }
        let savedItems = ShelfContentReader.savedItems(from: pasteboard)
        add(savedItems)
        return !savedItems.isEmpty
    }

    /// Shows the copy right away as "Copying…", and fills it in once the copy is done.
    private func addCopy(of original: URL) {
        let copyURL = ShelfStorage.newFolder().appending(path: original.lastPathComponent)
        let item = ShelfItem(copyOf: original, at: copyURL)
        guard !items.contains(where: { $0.dedupeKey == item.dedupeKey }) else { return }
        items.append(item)
        lastUsed = Date()
        copyingIDs.insert(item.id)
        Task {
            let copied = await ShelfStorage.copy(original, to: copyURL)
            copyingIDs.remove(item.id)
            let stillOnShelf = items.contains { $0.id == item.id }
            if copied && stillOnShelf {
                save()
            } else if !copied && stillOnShelf {
                NSSound.beep()
                remove([item.id])
            } else {
                ShelfStorage.deleteFolder(of: copyURL)
            }
        }
    }

    /// Tooki's own files are deleted with their items. `deleteAfter` gives an app the item was
    /// dropped into time to read the file, like a web upload field that sends it a bit later.
    func remove(_ ids: Set<ShelfItem.ID>, deleteAfter delay: Duration = .zero) {
        let removed = items.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        save()
        deleteOwnedFiles(of: removed.filter { $0.ownsFile && !copyingIDs.contains($0.id) }, after: delay)
        if items.isEmpty { isExpanded = false }
    }

    /// Drops items whose file was moved or deleted outside Tooki, e.g. in Finder or yazi.
    func dropMissingFiles() {
        let missing = items.filter { !copyingIDs.contains($0.id) && !$0.exists }
        remove(Set(missing.map(\.id)))
    }

    /// Called after items were dropped somewhere outside the shelf.
    func didDragOut(_ draggedItems: [ShelfItem]) {
        guard removeAfterDragOut else { return }
        remove(Set(draggedItems.map(\.id)), deleteAfter: .seconds(60))
    }

    private func deleteOwnedFiles(of removed: [ShelfItem], after delay: Duration) {
        guard !removed.isEmpty else { return }
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            removed.forEach { ShelfStorage.deleteFolder(of: $0.url) }
        }
    }

    func clear() {
        remove(Set(items.map(\.id)))
    }

    /// A plain click selects one item; ⌘ or ⇧ adds it to or removes it from the selection.
    func click(_ item: ShelfItem, modifiers: NSEvent.ModifierFlags) {
        cursor = item.id
        if modifiers.contains(.command) || modifiers.contains(.shift) {
            if selection.remove(item.id) == nil { selection.insert(item.id) }
        } else {
            selection = [item.id]
        }
    }

    /// Slides the list over to this item's details, and selects it.
    func showDetail(of item: ShelfItem) {
        cursor = item.id
        selection = [item.id]
        isShowingDetail = true
    }

    /// ↑ and ↓ select the next row up or down; with ⇧ that row is added to the selection.
    /// With nothing selected yet, ↓ starts at the top and ↑ at the bottom.
    func moveSelection(by offset: Int, extending: Bool) {
        guard !items.isEmpty else { return }
        let next: Int
        if let current = cursor.flatMap({ id in items.firstIndex { $0.id == id } }), !selection.isEmpty {
            next = min(max(current + offset, 0), items.count - 1)
        } else {
            next = offset > 0 ? 0 : items.count - 1
        }
        cursor = items[next].id
        if extending {
            selection.insert(items[next].id)
        } else {
            selection = [items[next].id]
        }
    }

    /// Dragging a selected item takes the whole selection along; any other item goes alone.
    func itemsToDrag(startingAt item: ShelfItem) -> [ShelfItem] {
        let dragged = selection.contains(item.id) ? selectedItems : [item]
        return dragged.filter { !copyingIDs.contains($0.id) }
    }

    private func save() {
        onChange()
    }
}

/// How dropped files go on the shelf.
enum ShelfAddMode {
    /// Links to the file where it is; dragging it out later can move it.
    case original
    /// Tooki's own copy; the original never moves.
    case copy
}

/// How a shelf goes away: hidden shelves can come back, closed ones are gone.
enum ShelfLeaving {
    case hiding, closing
}

/// What a shelf's buttons do to all of its items.
enum ShelfAction {
    case clear, delete
}
