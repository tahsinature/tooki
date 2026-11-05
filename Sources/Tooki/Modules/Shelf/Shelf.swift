import AppKit
import Observation

/// The items on the shelf, and which are selected. Saved in Application Support so the
/// shelf comes back after Tooki restarts.
@MainActor
@Observable
final class Shelf {
    private(set) var items: [ShelfItem] = []
    var selection: Set<ShelfItem.ID> = []
    var isExpanded = false
    /// Something is being dragged over the shelf.
    var dropTarget: ShelfDropTarget?
    /// Copies still being made. They show as "Copying…" and can't be dragged out yet.
    private(set) var copyingIDs: Set<ShelfItem.ID> = []
    @ObservationIgnored var removeAfterDragOut = true

    /// Runs after items were removed and the shelf became empty.
    @ObservationIgnored var onEmptied: () -> Void = {}
    @ObservationIgnored private let fileURL = StoragePaths.dataDirectory.appending(path: "shelf.json")

    var isEmpty: Bool { items.isEmpty }
    var selectedItems: [ShelfItem] { items.filter { selection.contains($0.id) } }
    var totalBytes: Int64 { items.compactMap(\.byteSize).reduce(0, +) }

    /// Files that were moved or deleted while Tooki wasn't running are left out.
    func load() {
        if let data = JSONFile.read(fileURL),
           let saved = try? JSONFile.decoder.decode([ShelfItem].self, from: data) {
            items = saved.filter(\.exists)
        }
        ShelfStorage.deleteUnused(keeping: items.filter(\.ownsFile).map(\.url))
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
        if items.isEmpty {
            isExpanded = false
            onEmptied()
        }
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
        if modifiers.contains(.command) || modifiers.contains(.shift) {
            if selection.remove(item.id) == nil { selection.insert(item.id) }
        } else {
            selection = [item.id]
        }
    }

    /// Dragging a selected item takes the whole selection along; any other item goes alone.
    func itemsToDrag(startingAt item: ShelfItem) -> [ShelfItem] {
        let dragged = selection.contains(item.id) ? selectedItems : [item]
        return dragged.filter { !copyingIDs.contains($0.id) }
    }

    /// Copies still being made aren't saved; if Tooki quits mid-copy they're simply gone.
    private func save() {
        let finished = items.filter { !copyingIDs.contains($0.id) }
        guard let data = try? JSONFile.encoder.encode(finished) else { return }
        try? JSONFile.write(data, to: fileURL)
    }
}

/// How dropped files go on the shelf.
enum ShelfAddMode {
    /// Links to the file where it is; dragging it out later can move it.
    case original
    /// Tooki's own copy; the original never moves.
    case copy
}
