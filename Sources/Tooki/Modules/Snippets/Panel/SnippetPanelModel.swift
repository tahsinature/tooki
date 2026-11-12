import Foundation
import Observation
import TookiKit

/// State of the snippets panel: search, collection filter, selection, the ⌘K menu and the edit form.
@MainActor
@Observable
final class SnippetPanelModel {
    /// A snippet being created or edited. Saving writes it back; going back discards it.
    struct Form {
        var draft: Snippet
        let isNew: Bool
    }

    var query = "" {
        didSet { if query != oldValue { selectedID = nil } }
    }
    /// `nil` shows every collection.
    var collectionFilter: String? {
        didSet { if collectionFilter != oldValue { selectedID = nil } }
    }
    var dynamicInputs: [String: String] = [:]
    var dynamicConfiguration: [String: String] = [:]
    var dynamicOutput: String?
    var dynamicError: String?
    var isRunning = false
    var runGeneration = 0

    var selectedID: Snippet.ID? { didSet { if oldValue != selectedID { resetDynamicRun() } } }
    /// Non-nil while the edit form replaces the list.
    var draftError: String?
    var form: Form?
    let actions = ActionsMenu<SnippetAction>()

    let snippets: JSONDocument<[Snippet]>
    let usage: SnippetUsage
    /// The app that was in front when the panel opened; pasting goes there.
    let targetAppName: String?

    init(snippets: JSONDocument<[Snippet]>, usage: SnippetUsage, targetAppName: String?) {
        self.snippets = snippets
        self.usage = usage
        self.targetAppName = targetAppName
        actions.rootActions = { [weak self] in
            guard let self, let snippet = selectedSnippet else { return [] }
            return SnippetAction.all(for: snippet, targetAppName: targetAppName)
        }
    }

    // MARK: - Browsing

    var collections: [String] {
        Set(snippets.value.map(\.collection).filter { !$0.isEmpty }).sorted()
    }

    /// Pinned first, then grouped by when each snippet was last used or changed.
    var sections: [PanelListSection<Snippet>] {
        let sorted = results.sorted { lastActivity(of: $0) > lastActivity(of: $1) }
        let pinned = sorted.filter(\.isPinned)
        let others = sorted.filter { !$0.isPinned }
        let pinnedSection = pinned.isEmpty ? [] : [PanelListSection(title: "Pinned", items: pinned)]
        return pinnedSection + PanelListSection.byDay(others, date: lastActivity)
    }

    var selectedSnippet: Snippet? {
        let ordered = orderedResults
        return ordered.first { $0.id == selectedID } ?? ordered.first
    }

    func moveSelection(by offset: Int) {
        let ordered = orderedResults
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.id == selectedSnippet?.id } ?? 0
        selectedID = ordered[min(max(current + offset, 0), ordered.count - 1)].id
    }

    func lastActivity(of snippet: Snippet) -> Date {
        usage.entry(for: snippet.id)?.lastUsed ?? snippet.modifiedAt ?? snippet.createdAt ?? .distantPast
    }

    // MARK: - Changes

    func togglePinOfSelected() {
        guard let snippet = selectedSnippet else { return }
        update(snippet.id) { $0.isPinned.toggle() }
        selectedID = snippet.id
    }

    /// Selects the next snippet so the keyboard keeps working after a delete.
    func deleteSelected() {
        guard let snippet = selectedSnippet else { return }
        let ordered = orderedResults
        let index = ordered.firstIndex { $0.id == snippet.id } ?? 0
        let neighbour = ordered.indices.contains(index + 1) ? ordered[index + 1] : ordered.dropLast().last
        snippets.value.removeAll { $0.id == snippet.id }
        selectedID = neighbour?.id
    }

    func startCreating() {
        actions.close()
        form = Form(draft: Snippet(name: "", collection: collectionFilter ?? "", text: ""), isNew: true)
    }

    func startEditingSelected() {
        guard let snippet = selectedSnippet else { return }
        actions.close()
        form = Form(draft: snippet, isNew: false)
    }

    /// Opens the create form filled in from the selected snippet. The keyword is left empty so
    /// two snippets don't expand from the same keyword.
    func startDuplicatingSelected() {
        guard let snippet = selectedSnippet else { return }
        actions.close()
        let copy = Snippet(name: "\(snippet.name) Copy", collection: snippet.collection, text: snippet.text, dynamic: snippet.dynamic, configuration: snippet.configuration)
        form = Form(draft: copy, isNew: true)
    }

    /// Whether another snippet already expands from the draft's keyword.
    var draftKeywordIsTaken: Bool {
        guard let draft = form?.draft, !draft.keyword.isEmpty else { return false }
        return snippets.value.contains { $0.id != draft.id && $0.keyword == draft.keyword }
    }

    var canSaveDraft: Bool {
        guard let draft = form?.draft else { return false }
        return !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && (!draft.text.isEmpty || draft.dynamic != nil)
    }

    /// Returns false when the draft is missing a name or text.
    func saveDraft() -> Bool {
        guard canSaveDraft, var draft = form?.draft else { return false }
        if draftKeywordIsTaken { draftError = "Another snippet already uses this keyword."; return false }
        if let definition = draft.dynamic {
            do { try definition.validate() } catch { draftError = error.localizedDescription; return false }
        }
        draftError = nil
        let now = Date()
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.collection = draft.collection.trimmingCharacters(in: .whitespaces)
        draft.modifiedAt = now
        draft.createdAt = draft.createdAt ?? now
        if let index = snippets.value.firstIndex(where: { $0.id == draft.id }) {
            snippets.value[index] = draft
        } else {
            snippets.value.append(draft)
        }
        form = nil
        // A new snippet may not match the current search or filter, so show it rather than hide it.
        if !results.contains(where: { $0.id == draft.id }) {
            query = ""
            collectionFilter = nil
        }
        selectedID = draft.id
        return true
    }

    // MARK: - Private

    private var orderedResults: [Snippet] { sections.flatMap(\.items) }

    private var results: [Snippet] {
        snippets.value.filter { snippet in
            (collectionFilter == nil || snippet.collection == collectionFilter) && snippet.matches(query)
        }
    }

    private func update(_ id: Snippet.ID, change: (inout Snippet) -> Void) {
        guard let index = snippets.value.firstIndex(where: { $0.id == id }) else { return }
        change(&snippets.value[index])
    }
}
