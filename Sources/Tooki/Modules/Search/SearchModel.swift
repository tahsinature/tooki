import AppKit
import ComposableArchitecture
import Observation
import SearchFeature
import TookiDesignSystem
import TookiKit

/// Native rendering values corresponding to a reducer-owned result section.
struct SearchSection: Identifiable {
    let title: String
    let items: [SearchItem]
    var id: String { title }
}

/// Connects portable launcher state to native images, calculator output and executable callbacks.
@MainActor
@Observable
final class SearchModel {
    let store: StoreOf<SearchFeature>
    let navigation = PanelKeyboardNavigation()
    let filterGroups: [SearchItem.Group]
    let placeholder: String
    let title: String
    let icon: PanelIcon
    private(set) var sections: [SearchSection] = []
    private(set) var results: [SearchItem] = []
    @ObservationIgnored private var itemsByID: [String: SearchItem]
    @ObservationIgnored private var calculation: SearchItem?
    private let calculate: (String) -> SearchItem?

    var query: String {
        get { store.query }
        set {
            guard newValue != store.query else { return }
            updateCalculation(query: newValue, filter: store.groupFilter)
            store.send(.queryChanged(newValue, calculation: calculation?.metadata, at: .now))
            updateNativeResults()
        }
    }
    var groupFilter: SearchItem.Group? {
        get { store.groupFilter }
        set {
            guard newValue != store.groupFilter else { return }
            updateCalculation(query: store.query, filter: newValue)
            store.send(.groupFilterChanged(newValue, calculation: calculation?.metadata, at: .now))
            updateNativeResults()
        }
    }
    var selection: Int {
        get { store.selection }
        set { store.send(.selectionChanged(newValue)) }
    }
    var isShowingActions: Bool {
        get { store.isShowingActions }
        set { store.send(.actionsPresented(newValue)) }
    }
    var menuQuery: String {
        get { store.menuQuery }
        set { store.send(.menuQueryChanged(newValue)) }
    }
    var actionSelection: Int {
        get { store.actionSelection }
        set { store.send(.actionSelectionChanged(newValue)) }
    }

    init(items: [SearchItem], placeholder: String, title: String, icon: PanelIcon,
         filterGroups: [SearchItem.Group] = [], history: LaunchHistory,
         calculate: @escaping (String) -> SearchItem? = { _ in nil }) {
        self.placeholder = placeholder
        self.title = title
        self.icon = icon
        self.filterGroups = filterGroups
        self.calculate = calculate
        itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        store = Store(initialState: SearchFeature.State(items: items.map { $0.metadata }, history: history)) { SearchFeature() }
        updateNativeResults()
    }

    func refresh(items: [SearchItem], history: LaunchHistory) {
        itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        updateCalculation(query: store.query, filter: store.groupFilter)
        store.send(.refreshed(items.map { $0.metadata }, history: history, calculation: calculation?.metadata, at: .now))
        updateNativeResults()
    }

    var selectedItem: SearchItem? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    var menuActions: [SearchAction] {
        let actions = selectedItem?.actions ?? []
        let byID = Dictionary(actions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return store.menuActions.compactMap { byID[$0.id] }
    }

    var selectedMenuAction: SearchAction? {
        let actions = menuActions
        return actions.indices.contains(actionSelection) ? actions[actionSelection] : nil
    }

    func moveSelection(by offset: Int) { store.send(.moveSelection(offset)) }
    func moveActionSelection(by offset: Int) { store.send(.moveActionSelection(offset)) }
    func resetPosition() {
        store.send(.resetPosition)
        navigation.moved(in: .results)
    }

    private func updateCalculation(query: String, filter: SearchItem.Group?) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        calculation = filter == nil && !trimmed.isEmpty ? calculate(trimmed) : nil
    }

    /// Cache native rows only when results change, not on every selection or body evaluation.
    private func updateNativeResults() {
        sections = store.sections.map { section in
            SearchSection(title: section.title, items: section.items.compactMap { entry in
                calculation?.id == entry.id ? calculation : itemsByID[entry.id]
            })
        }
        results = sections.flatMap(\.items)
    }
}
