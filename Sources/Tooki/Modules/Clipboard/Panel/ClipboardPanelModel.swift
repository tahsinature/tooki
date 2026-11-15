import TookiDesignSystem
import AppKit
import ClipboardFeature
import ComposableArchitecture
import Observation
import TookiKit

/// Connects the feature store to shared panel infrastructure and native action menus.
@MainActor
@Observable
final class ClipboardPanelModel {
    let store: StoreOf<ClipboardFeature>
    let navigation = PanelKeyboardNavigation()
    let actions = ActionsMenu<ClipboardAction>()
    let history: ClipboardHistory
    var targetAppName: String?
    private let groupByDate: () -> Bool

    var query: String {
        get { store.query }
        set { store.send(.queryChanged(newValue)) }
    }

    var typeFilter: ClipboardContentType? {
        get { store.typeFilter }
        set { store.send(.typeFilterChanged(newValue)) }
    }

    var selectedID: ClipboardItem.ID? {
        get { store.selectedID }
        set { store.send(.selectionChanged(newValue)) }
    }

    init(history: ClipboardHistory, targetAppName: String?, groupByDate: @escaping () -> Bool = { true }) {
        self.history = history
        self.targetAppName = targetAppName
        self.groupByDate = groupByDate
        store = Store(initialState: ClipboardFeature.State(items: history.items, sourceNames: Self.sourceNames(history.items))) {
            ClipboardFeature()
        } withDependencies: {
            $0.clipboardClient = ClipboardClient(
                copy: { item in await history.copy(item) },
                paste: { item in await history.paste(item) },
                togglePin: { item in await history.togglePin(item) },
                remove: { item in await history.remove(item) }
            )
        }
        actions.rootActions = { [weak self] in
            guard let self, let item = selectedItem else { return [] }
            return ClipboardAction.all(for: item, targetAppName: self.targetAppName)
        }
    }

    var orderedResults: [ClipboardItem] { store.orderedResults }
    var selectedItem: ClipboardItem? { store.selectedItem }
    var itemCountLabel: String { store.itemCountLabel }
    var pinned: [ClipboardItem] { Array(orderedResults.prefix(store.pinnedCount)) }
    var recent: [ClipboardItem] { Array(orderedResults.dropFirst(store.pinnedCount)) }

    var sections: [PanelListSection<ClipboardItem>] {
        let recentSections = groupByDate()
            ? PanelListSection.byDay(recent, date: \.copiedAt)
            : [PanelListSection(title: nil, items: recent)]
        return [PanelListSection(title: "Pinned", items: pinned)] + recentSections
    }

    func refreshHistory() {
        store.send(.historyChanged(history.items, sourceNames: Self.sourceNames(history.items)))
    }

    func resetPosition() {
        store.send(.resetPosition)
        navigation.moved(in: .results)
    }

    func moveSelection(by offset: Int) { store.send(.moveSelection(offset)) }
    func togglePinOfSelected() { store.send(.togglePin) }
    func deleteSelected() { store.send(.deleteSelected) }
    func copySelected() { store.send(.copySelected) }
    func pasteSelected() { store.send(.pasteSelected) }

    func showOpenWith() {
        guard let item = selectedItem, item.canBeUsed, ClipboardOpenWith.canOpen(item) else { return }
        actions.showSubmenu(title: "Open With", actions: ClipboardOpenWith.actions(for: item), parentID: .openWith)
    }

    private static func sourceNames(_ items: [ClipboardItem]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: Set(items.compactMap(\.sourceApp)).compactMap { id in
            SourceApp.named(id).map { (id, $0.name) }
        })
    }
}
