import TookiDesignSystem
import Foundation
import ComposableArchitecture
import ShelfFeature
import Observation

/// State of the shelf manager: the list of shelves, or the items of the one that's open.
@MainActor
@Observable
final class ShelfManagerModel {
    let navigation = PanelKeyboardNavigation()

    func resetPosition() {
        refresh()
        store.send(.resetPosition)
        navigation.moved(in: .results)
    }

    let library: ShelfLibrary
    let actions = ActionsMenu<ShelfManagerAction>()

    let store: StoreOf<ShelfManagerFeature>
    var query: String {
        get { store.query }
        set { store.send(.queryChanged(newValue)) }
    }
    var renamingShelfID: Shelf.ID? { store.renamingShelfID }
    var openShelfID: Shelf.ID? { store.openShelfID }
    var selectedShelfID: Shelf.ID? {
        get { store.selectedShelfID }
        set { store.send(.shelfSelected(newValue)) }
    }
    var selectedItemID: ShelfItem.ID? {
        get { store.selectedItemID }
        set { store.send(.itemSelected(newValue)) }
    }
    private(set) var imageConversion: ShelfImageConversionModel?
    var isShowingConversion: Bool { store.isShowingConversion }

    /// The conversion page owns typing while the prior search is preserved for Back.
    var displayedQuery: String {
        get { isShowingConversion ? "" : query }
        set { if !isShowingConversion { query = newValue } }
    }

    init(library: ShelfLibrary) {
        self.library = library
        store = Store(initialState: ShelfManagerFeature.State(shelves: Self.summaries(library))) { ShelfManagerFeature() }
        actions.rootActions = { [weak self] in
            guard let self, renamingShelfID == nil, !isShowingConversion else { return [] }
            if let openShelf, let selectedItem { return ShelfManagerAction.forItem(selectedItem, in: openShelf) }
            if openShelf != nil { return [] }
            return selectedShelf == nil ? [] : ShelfManagerAction.forShelf
        }
    }

    /// `nil` once the open shelf was closed, e.g. after its last item was removed.
    var openShelf: Shelf? { library.shelves.first { $0.id == openShelfID } }

    // MARK: - Shelves

    /// Most recently used first. Searching also finds shelves holding a matching item.
    var shelves: [Shelf] {
        let byID = Dictionary(uniqueKeysWithValues: library.shelves.map { ($0.id, $0) })
        return store.visibleShelves.compactMap { byID[$0.id] }
    }

    var librarySnapshot: [ShelfSummary] { Self.summaries(library) }
    func refresh() { store.send(.refreshed(librarySnapshot)) }
    private static func summaries(_ library: ShelfLibrary) -> [ShelfSummary] {
        library.shelves.map { shelf in
            ShelfSummary(id: shelf.id, name: shelf.name, lastUsed: shelf.lastUsed,
                         items: shelf.items.map { ShelfSummary.Item(id: $0.id, name: $0.name) })
        }
    }

    var selectedShelf: Shelf? {
        shelves.first { $0.id == selectedShelfID } ?? shelves.first
    }

    func open(_ shelf: Shelf) {
        actions.close()
        refresh()
        store.send(.open(shelf.id))
    }

    func select(_ shelf: Shelf) {
        actions.close()
        refresh()
        store.send(.select(shelf.id))
    }

    func closeOpenShelf() {
        actions.close()
        store.send(.closeShelf)
    }

    // MARK: - Renaming

    var renamingShelf: Shelf? { library.shelves.first { $0.id == renamingShelfID } }

    func startRenaming(_ shelf: Shelf) {
        actions.close()
        refresh()
        store.send(.startRenaming(shelf.id))
    }

    func finishRenaming(save: Bool) {
        guard let shelf = renamingShelf else { return }
        if save { shelf.rename(to: query) }
        store.send(.finishRenaming)
        refresh()
    }

    // MARK: - Items

    var items: [ShelfItem] {
        let byID = Dictionary(uniqueKeysWithValues: (openShelf?.items ?? []).map { ($0.id, $0) })
        return store.visibleItems.compactMap { byID[$0.id] }
    }

    var selectedItem: ShelfItem? {
        items.first { $0.id == selectedItemID } ?? items.first
    }

    func beginConversion(onClose: @escaping () -> Void) {
        guard imageConversion == nil, let shelf = openShelf, let item = selectedItem,
              shelf.imageConversion == nil, shelf.canConvertImages([item]) else { return }
        actions.close()
        let conversion = ShelfImageConversionModel(items: [item], shelf: shelf) { [weak self] in
            self?.endConversion()
            onClose()
        }
        conversion.onSaved = { [weak self] ids in
            guard let self, let id = ids.first else { return }
            refresh()
            if !items.contains(where: { $0.id == id }) { query = "" }
            selectedItemID = id
        }
        imageConversion = conversion
        store.send(.conversionPresented(true))
    }

    private func endConversion() {
        guard let id = imageConversion?.id else { return }
        store.send(.conversionPresented(false))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(ShelfMotion.duration))
            guard let self, !isShowingConversion, imageConversion?.id == id else { return }
            imageConversion = nil
        }
    }

    // MARK: - Moving

    func moveSelection(by offset: Int) {
        refresh()
        store.send(.moveSelection(offset))
    }
}
