import ComposableArchitecture
import Foundation
import TookiKit

/// Launcher ranking, selection and action-menu state. Native integrations supply metadata snapshots.
@Reducer
public struct SearchFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var items: [SearchEntry]
        public var history: LaunchHistory
        public var query = ""
        public var groupFilter: SearchGroup?
        public var selection = 0
        public var isShowingActions = false
        public var menuQuery = ""
        public var actionSelection = 0
        public internal(set) var sections: [SearchSectionState] = []
        public internal(set) var results: [SearchEntry] = []
        public internal(set) var menuActions: [SearchActionMetadata] = []
        var calculation: SearchEntry?

        public init(items: [SearchEntry], history: LaunchHistory = LaunchHistory(), now: Date = .now) {
            self.items = items
            self.history = history
            rebuildResults(at: now)
        }

        public var selectedItem: SearchEntry? {
            results.indices.contains(selection) ? results[selection] : nil
        }

        mutating func rebuildActions() {
            let words = menuQuery.lowercased().split(separator: " ")
            menuActions = selectedItem?.actions.filter { action in
                words.allSatisfy { action.title.lowercased().contains($0) }
            } ?? []
        }

        mutating func presentActions(_ showing: Bool) {
            guard isShowingActions != showing else { return }
            isShowingActions = showing
            menuQuery = ""
            actionSelection = 0
        }
    }

    public enum Action: Equatable, Sendable {
        // Time is part of the input snapshot, so ranking is deterministic without reading a clock.
        case queryChanged(String, calculation: SearchEntry?, at: Date)
        case groupFilterChanged(SearchGroup?, calculation: SearchEntry?, at: Date)
        case refreshed([SearchEntry], history: LaunchHistory, calculation: SearchEntry?, at: Date)
        case selectionChanged(Int)
        case moveSelection(Int)
        case resetPosition
        case actionsPresented(Bool)
        case menuQueryChanged(String)
        case actionSelectionChanged(Int)
        case moveActionSelection(Int)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .queryChanged(query, calculation, now):
                guard state.query != query else { return .none }
                state.query = query
                state.calculation = calculation
                state.selection = 0
                state.presentActions(false)
                state.rebuildResults(at: now)
            case let .groupFilterChanged(filter, calculation, now):
                guard state.groupFilter != filter else { return .none }
                state.groupFilter = filter
                state.calculation = calculation
                state.selection = 0
                state.presentActions(false)
                state.rebuildResults(at: now)
            case let .refreshed(items, history, calculation, now):
                let selectedID = state.selectedItem?.id
                state.items = items
                state.history = history
                state.calculation = calculation
                state.rebuildResults(at: now)
                state.selection = state.results.firstIndex { $0.id == selectedID } ?? 0
                state.rebuildActions()
            case .selectionChanged(let selection):
                state.selection = selection
                state.rebuildActions()
            case .moveSelection(let offset):
                state.selection = Self.moved(state.selection, by: offset, count: state.results.count)
                state.rebuildActions()
            case .resetPosition:
                state.selection = 0
                state.rebuildActions()
            case .actionsPresented(let showing):
                state.presentActions(showing)
                state.rebuildActions()
            case .menuQueryChanged(let query):
                guard state.menuQuery != query else { return .none }
                state.menuQuery = query
                state.actionSelection = 0
                state.rebuildActions()
            case .actionSelectionChanged(let selection):
                state.actionSelection = selection
            case .moveActionSelection(let offset):
                state.actionSelection = Self.moved(state.actionSelection, by: offset, count: state.menuActions.count)
            }
            return .none
        }
    }

    private static func moved(_ index: Int, by offset: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let current = min(max(index, 0), count - 1)
        let bounded = max(-count, min(offset, count))
        return min(max(current + bounded, 0), count - 1)
    }
}
