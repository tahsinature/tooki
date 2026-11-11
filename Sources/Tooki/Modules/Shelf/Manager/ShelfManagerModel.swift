import Foundation
import Observation

/// State of the shelf manager: the list of shelves, or the items of the one that's open.
@MainActor
@Observable
final class ShelfManagerModel {
    let library: ShelfLibrary
    let actions = ActionsMenu<ShelfManagerAction>()

    var query = "" {
        didSet {
            // While renaming, the search field holds the new name instead of a search.
            if query != oldValue, renamingShelfID == nil { selectedShelfID = nil; selectedItemID = nil }
        }
    }
    /// The shelf being renamed in the search field.
    private(set) var renamingShelfID: Shelf.ID?
    /// The shelf whose items are listed. `nil` lists the shelves.
    private(set) var openShelfID: Shelf.ID?
    var selectedShelfID: Shelf.ID?
    var selectedItemID: ShelfItem.ID?

    init(library: ShelfLibrary) {
        self.library = library
        actions.rootActions = { [weak self] in
            guard let self, renamingShelfID == nil else { return [] }
            if let openShelf { return selectedItem == nil ? [] : ShelfManagerAction.forItem(in: openShelf) }
            return selectedShelf == nil ? [] : ShelfManagerAction.forShelf
        }
    }

    /// `nil` once the open shelf was closed, e.g. after its last item was removed.
    var openShelf: Shelf? { library.shelves.first { $0.id == openShelfID } }

    // MARK: - Shelves

    /// Most recently used first. Searching also finds shelves holding a matching item.
    var shelves: [Shelf] {
        library.shelves
            .filter { renamingShelfID != nil || query.isEmpty || matches($0.name) || $0.items.contains { matches($0.name) } }
            .sorted { $0.lastUsed > $1.lastUsed }
    }

    var selectedShelf: Shelf? {
        shelves.first { $0.id == selectedShelfID } ?? shelves.first
    }

    func open(_ shelf: Shelf) {
        actions.close()
        query = ""
        openShelfID = shelf.id
        selectedShelfID = shelf.id
        selectedItemID = nil
    }

    /// Lists the shelves again with `shelf` selected, e.g. after making it.
    func select(_ shelf: Shelf) {
        if openShelfID != nil { closeOpenShelf() }
        actions.close()
        query = ""
        selectedShelfID = shelf.id
    }

    /// Back to the list of shelves, with the one that was open still selected.
    func closeOpenShelf() {
        let id = openShelfID
        actions.close()
        openShelfID = nil
        query = ""
        selectedShelfID = id
    }

    // MARK: - Renaming

    var renamingShelf: Shelf? { library.shelves.first { $0.id == renamingShelfID } }

    func startRenaming(_ shelf: Shelf) {
        actions.close()
        renamingShelfID = shelf.id
        selectedShelfID = shelf.id
        query = shelf.name
    }

    /// Saves the typed name, or keeps the old one when `save` is `false`.
    func finishRenaming(save: Bool) {
        guard let shelf = renamingShelf else { return }
        if save { shelf.rename(to: query) }
        renamingShelfID = nil
        query = ""
        selectedShelfID = shelf.id
    }

    // MARK: - Items

    var items: [ShelfItem] {
        (openShelf?.items ?? []).filter { query.isEmpty || matches($0.name) }
    }

    var selectedItem: ShelfItem? {
        items.first { $0.id == selectedItemID } ?? items.first
    }

    // MARK: - Moving

    func moveSelection(by offset: Int) {
        guard renamingShelfID == nil else { return }
        if openShelf != nil {
            selectedItemID = neighbour(of: selectedItem?.id, in: items.map(\.id), by: offset)
        } else {
            selectedShelfID = neighbour(of: selectedShelf?.id, in: shelves.map(\.id), by: offset)
        }
    }

    private func neighbour<ID: Equatable>(of current: ID?, in ids: [ID], by offset: Int) -> ID? {
        guard !ids.isEmpty else { return nil }
        let index = ids.firstIndex { $0 == current } ?? 0
        return ids[min(max(index + offset, 0), ids.count - 1)]
    }

    private func matches(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespaces))
    }
}
