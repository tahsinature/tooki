import ComposableArchitecture
import Foundation
import Observation
import SnippetFeature
import TookiDesignSystem
import TookiKit

/// Adapts snippet state to shared panels and the existing native JSON document/inserter.
@MainActor
@Observable
final class SnippetPanelModel {
    typealias Form = SnippetFormState

    let store: StoreOf<SnippetFeature>
    let navigation = PanelKeyboardNavigation()
    let actions = ActionsMenu<SnippetAction>()
    let snippets: JSONDocument<[Snippet]>
    let usage: SnippetUsage
    var targetAppName: String?
    private let groupByDate: () -> Bool

    var query: String {
        get { store.query }
        set { store.send(.queryChanged(newValue)) }
    }
    var collectionFilter: String? {
        get { store.collectionFilter }
        set { store.send(.collectionFilterChanged(newValue)) }
    }
    var selectedID: Snippet.ID? {
        get { store.selectedID }
        set { store.send(.selectionChanged(newValue)) }
    }
    var form: Form? {
        get { store.form }
        set { store.send(.formChanged(newValue)) }
    }

    init(snippets: JSONDocument<[Snippet]>, usage: SnippetUsage, targetAppName: String?,
         groupByDate: @escaping () -> Bool = { true }, inserter: SnippetInserter = SnippetInserter()) {
        self.snippets = snippets
        self.usage = usage
        self.targetAppName = targetAppName
        self.groupByDate = groupByDate
        store = Store(initialState: SnippetFeature.State(items: snippets.value, lastUsed: Self.lastUsed(usage))) {
            SnippetFeature()
        } withDependencies: {
            $0.snippetClient = SnippetClient(
                copy: { snippet in await MainActor.run { usage.record(snippet.id); inserter.copy(snippet) } },
                paste: { snippet in await MainActor.run { usage.record(snippet.id); inserter.insert(snippet) } }
            )
        }
        actions.rootActions = { [weak self] in
            guard let self, let snippet = selectedSnippet else { return [] }
            return SnippetAction.all(for: snippet, targetAppName: self.targetAppName)
        }
    }

    var collections: [String] { store.collections }
    var orderedResults: [Snippet] { store.orderedResults }
    var selectedSnippet: Snippet? { store.selectedSnippet }
    var draftKeywordIsTaken: Bool { store.draftKeywordIsTaken }
    var canSaveDraft: Bool { store.canSaveDraft }

    var sections: [PanelListSection<Snippet>] {
        let ordered = orderedResults
        let pinned = Array(ordered.prefix(store.pinnedCount))
        let others = Array(ordered.dropFirst(store.pinnedCount))
        let pinnedSection = pinned.isEmpty ? [] : [PanelListSection(title: "Pinned", items: pinned)]
        let recent = groupByDate()
            ? PanelListSection.byDay(others, date: lastActivity)
            : [PanelListSection(title: nil, items: others)]
        return pinnedSection + recent
    }

    func refreshData() {
        store.send(.dataChanged(snippets.value, lastUsed: Self.lastUsed(usage)))
    }

    func lastActivity(of snippet: Snippet) -> Date {
        store.lastUsed[snippet.id] ?? snippet.modifiedAt ?? snippet.createdAt ?? .distantPast
    }
    func moveSelection(by offset: Int) { store.send(.moveSelection(offset)) }
    func copySelected() { store.send(.copySelected) }
    func pasteSelected() { store.send(.pasteSelected) }

    func resetPosition() {
        store.send(.resetPosition)
        navigation.moved(in: .results)
    }

    func togglePinOfSelected() { mutate(.togglePin) }
    func deleteSelected() { mutate(.deleteSelected) }

    func startCreating() {
        actions.close()
        store.send(.startCreating)
    }
    func startEditingSelected() {
        actions.close()
        store.send(.startEditing)
    }
    func startDuplicatingSelected() {
        actions.close()
        store.send(.startDuplicating)
    }

    func saveDraft() -> Bool {
        guard canSaveDraft else { return false }
        mutate(.saveDraft)
        return true
    }

    /// Keep the document update synchronous, preserving its existing save/reload contract.
    private func mutate(_ action: SnippetFeature.Action) {
        refreshData()
        store.send(action)
        snippets.value = store.items
    }

    private static func lastUsed(_ usage: SnippetUsage) -> [Snippet.ID: Date] {
        Dictionary(uniqueKeysWithValues: usage.history.entries.compactMap { key, entry in
            UUID(uuidString: key).map { ($0, entry.lastUsed) }
        })
    }
}
