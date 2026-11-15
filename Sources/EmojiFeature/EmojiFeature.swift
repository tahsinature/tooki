import ComposableArchitecture
import TookiKit

@Reducer
public struct EmojiFeature {
    public struct Section: Equatable, Identifiable, Sendable {
        public let title: String
        public let emoji: [Emoji]
        public var id: String { title }
    }

    @ObservableState
    public struct State: Equatable {
        public var query = ""
        public var selection = 0
        public var isShowingActions = false
        public var actionSelection = 0
        public var actionQuery = ""
        public var sections: [Section] = []
        public var results: [Emoji] = []
        public var recentCharacters: [String]

        public init(recentCharacters: [String]) {
            self.recentCharacters = recentCharacters
            rebuild()
        }

        public var selected: Emoji? { results.indices.contains(selection) ? results[selection] : nil }

        public var visibleActions: [EmojiCommand] {
            let words = actionQuery.lowercased().split(separator: " ")
            return EmojiCommand.allCases.filter { action in
                words.allSatisfy { action.title.lowercased().contains($0) }
            }
        }
        public var selectedAction: EmojiCommand? {
            visibleActions.indices.contains(actionSelection) ? visibleActions[actionSelection] : nil
        }

        mutating func rebuild() {
            selection = 0
            isShowingActions = false
            actionSelection = 0
            actionQuery = ""
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                let byCharacter = Dictionary(uniqueKeysWithValues: EmojiCatalog.all.map { ($0.character, $0) })
                let recent = recentCharacters.compactMap { byCharacter[$0] }
                sections = recent.isEmpty ? [] : [Section(title: "Recently Used", emoji: recent)]
                sections += EmojiCatalog.groups.map { group in
                    Section(title: group, emoji: EmojiCatalog.all.filter { $0.group == group })
                }
            } else {
                sections = [Section(title: "Results", emoji: EmojiCatalog.search(query))]
            }
            sections.removeAll { $0.emoji.isEmpty }
            results = sections.flatMap(\.emoji)
        }
    }

    public enum Action: Equatable {
        case queryChanged(String)
        case selectionChanged(Int)
        case moveSelection(Int)
        case actionsPresented(Bool)
        case actionQueryChanged(String)
        case actionSelectionChanged(Int)
        case moveActionSelection(Int)
        case recentChanged([String])
        case resetPosition
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .queryChanged(query):
                guard state.query != query else { return .none }
                state.query = query
                state.rebuild()
            case let .recentChanged(characters):
                guard state.recentCharacters != characters else { return .none }
                let selected = state.selected
                state.recentCharacters = characters
                state.rebuild()
                if let selected, let index = state.results.firstIndex(of: selected) { state.selection = index }
            case let .selectionChanged(index): state.selection = Self.clamped(index, count: state.results.count)
            case let .moveSelection(offset):
                state.selection += min(max(offset, -state.selection), max(0, state.results.count - 1 - state.selection))
            case let .actionsPresented(shown):
                state.isShowingActions = shown
                state.actionSelection = 0
                state.actionQuery = ""
            case let .actionQueryChanged(query):
                guard query != state.actionQuery else { return .none }
                state.actionQuery = query
                state.actionSelection = 0
            case let .actionSelectionChanged(index): state.actionSelection = Self.clamped(index, count: state.visibleActions.count)
            case let .moveActionSelection(offset):
                state.actionSelection += min(max(offset, -state.actionSelection), max(0, state.visibleActions.count - 1 - state.actionSelection))
            case .resetPosition: state.selection = 0
            }
            return .none
        }
    }

    private static func clamped(_ index: Int, count: Int) -> Int { min(max(index, 0), max(0, count - 1)) }
}
