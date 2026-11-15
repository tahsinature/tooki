import ComposableArchitecture
import Foundation
import TookiKit

/// Snippet browsing and editing, independent of native windows and storage.
@Reducer
public struct SnippetFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var items: [Snippet]
        public var query = ""
        public var collectionFilter: String?
        public var selectedID: Snippet.ID?
        public var form: SnippetFormState?
        public internal(set) var orderedResults: [Snippet] = []
        public internal(set) var pinnedCount = 0
        public internal(set) var collections: [String] = []
        public internal(set) var lastUsed: [Snippet.ID: Date]

        public init(items: [Snippet] = [], lastUsed: [Snippet.ID: Date] = [:]) {
            self.items = items
            self.lastUsed = lastUsed
            rebuildResults()
        }

        public var selectedSnippet: Snippet? {
            orderedResults.first { $0.id == selectedID } ?? orderedResults.first
        }

        public var draftKeywordIsTaken: Bool {
            guard let draft = form?.draft, !draft.keyword.isEmpty else { return false }
            return items.contains { $0.id != draft.id && $0.keyword == draft.keyword }
        }

        public var canSaveDraft: Bool {
            guard let draft = form?.draft else { return false }
            return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !draft.text.isEmpty
        }

    }

    public enum Action: Equatable, Sendable {
        case queryChanged(String)
        case collectionFilterChanged(String?)
        case selectionChanged(Snippet.ID?)
        case formChanged(SnippetFormState?)
        case dataChanged([Snippet], lastUsed: [Snippet.ID: Date])
        case moveSelection(Int)
        case resetPosition
        case togglePin, deleteSelected
        case startCreating, startEditing, startDuplicating, saveDraft
        case copySelected, pasteSelected
    }

    @Dependency(\.snippetClient) var client
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .queryChanged(let query):
                guard state.query != query else { return .none }
                state.query = query
                state.selectedID = nil
                state.rebuildResults()
            case .collectionFilterChanged(let filter):
                guard state.collectionFilter != filter else { return .none }
                state.collectionFilter = filter
                state.selectedID = nil
                state.rebuildResults()
            case .selectionChanged(let id):
                state.selectedID = id
            case .formChanged(let form):
                state.form = form
            case let .dataChanged(items, lastUsed):
                guard state.items != items || state.lastUsed != lastUsed else { return .none }
                state.items = items
                state.lastUsed = lastUsed
                state.rebuildResults()
            case .moveSelection(let offset):
                let results = state.orderedResults
                guard !results.isEmpty else { return .none }
                let selectedID = state.selectedID
                let current = results.firstIndex { $0.id == selectedID } ?? 0
                let bounded = max(-results.count, min(offset, results.count))
                state.selectedID = results[min(max(current + bounded, 0), results.count - 1)].id
            case .resetPosition:
                state.selectedID = state.orderedResults.first?.id
            case .togglePin:
                guard let snippet = state.selectedSnippet,
                      let index = state.items.firstIndex(where: { $0.id == snippet.id }) else { return .none }
                state.items[index].isPinned.toggle()
                state.selectedID = snippet.id
                state.rebuildResults()
            case .deleteSelected:
                guard let snippet = state.selectedSnippet else { return .none }
                let index = state.orderedResults.firstIndex { $0.id == snippet.id } ?? 0
                let next = state.orderedResults.dropFirst(index + 1).first ?? state.orderedResults.prefix(index).last
                state.items.removeAll { $0.id == snippet.id }
                state.selectedID = next?.id
                state.rebuildResults()
            case .startCreating:
                state.form = SnippetFormState(draft: Snippet(id: uuid(), name: "", collection: state.collectionFilter ?? "", text: ""), isNew: true)
            case .startEditing:
                guard let snippet = state.selectedSnippet else { return .none }
                state.form = SnippetFormState(draft: snippet, isNew: false)
            case .startDuplicating:
                guard let snippet = state.selectedSnippet else { return .none }
                state.form = SnippetFormState(
                    draft: Snippet(id: uuid(), name: "\(snippet.name) Copy", collection: snippet.collection, text: snippet.text), isNew: true
                )
            case .saveDraft:
                state.saveDraft(at: now)
            case .copySelected:
                guard let snippet = state.selectedSnippet else { return .none }
                return .run { [client] _ in await client.copy(snippet) }
            case .pasteSelected:
                guard let snippet = state.selectedSnippet else { return .none }
                return .run { [client] _ in await client.paste(snippet) }
            }
            return .none
        }
    }
}
