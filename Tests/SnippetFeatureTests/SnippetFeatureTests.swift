import ComposableArchitecture
import Foundation
import Testing
import TookiKit
@testable import SnippetFeature

@MainActor
struct SnippetFeatureTests {
    @Test func filteringAndActivityOrderKeepPinsAndUnchangedSelection() async {
        let old = Snippet(name: "Old", keyword: ";work", collection: "Work", text: "reply")
        let used = Snippet(name: "Used", collection: "Work", text: "reply")
        let pin = Snippet(name: "Pinned", collection: "General", text: "hello", isPinned: true)
        let now = Date(timeIntervalSince1970: 100)
        let store = TestStore(initialState: SnippetFeature.State(items: [old, used, pin], lastUsed: [used.id: now])) { SnippetFeature() }
        #expect(store.state.orderedResults == [pin, used, old])
        #expect(store.state.collections == ["General", "Work"])
        await store.send(.selectionChanged(old.id)) { $0.selectedID = old.id }
        await store.send(.queryChanged(""))
        await store.send(.collectionFilterChanged("Work")) {
            $0.collectionFilter = "Work"
            $0.selectedID = nil
            $0.pinnedCount = 0
            $0.orderedResults = [used, old]
        }
        await store.send(.selectionChanged(old.id)) { $0.selectedID = old.id }
        await store.send(.collectionFilterChanged("Work"))
        await store.send(.queryChanged("work ;work reply")) {
            $0.query = "work ;work reply"
            $0.selectedID = nil
            $0.orderedResults = [old]
        }
    }

    @Test func creatingValidatesAndRevealsTheSavedDraftWithoutBlockingKeywordWarnings() async {
        let existing = Snippet(name: "Existing", keyword: ";same", collection: "Work", text: "Original")
        var state = SnippetFeature.State(items: [existing])
        state.query = "Existing"
        state.collectionFilter = "Work"
        let id = UUID()
        let now = Date(timeIntervalSince1970: 100)
        let store = TestStore(initialState: state) { SnippetFeature() } withDependencies: {
            $0.uuid = .constant(id)
            $0.date.now = now
        }
        var form = SnippetFormState(draft: Snippet(id: id, name: "", collection: "Work", text: ""), isNew: true)
        await store.send(.startCreating) { $0.form = form }
        await store.send(.saveDraft)
        #expect(!store.state.canSaveDraft)
        form.draft.name = "  New  "
        form.draft.collection = " Other "
        form.draft.keyword = ";same"
        form.draft.text = "New text"
        await store.send(.formChanged(form)) { $0.form = form }
        #expect(store.state.draftKeywordIsTaken)
        #expect(store.state.canSaveDraft)
        var saved = form.draft
        saved.name = "New"
        saved.collection = "Other"
        saved.createdAt = now
        saved.modifiedAt = now
        await store.send(.saveDraft) {
            $0.items = [existing, saved]
            $0.orderedResults = [saved, existing]
            $0.collections = ["Other", "Work"]
            $0.form = nil
            $0.query = ""
            $0.collectionFilter = nil
            $0.selectedID = id
        }
    }

    @Test func duplicateAndCancelLeaveSavedDataUntouchedAndEditingPreservesIdentity() async {
        let created = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 100)
        let original = Snippet(name: "Original", keyword: ";original", collection: "Work", text: "Body", isPinned: true, createdAt: created)
        let id = UUID()
        let store = TestStore(initialState: SnippetFeature.State(items: [original])) { SnippetFeature() } withDependencies: {
            $0.uuid = .constant(id)
            $0.date.now = now
        }
        let copy = Snippet(id: id, name: "Original Copy", collection: "Work", text: "Body")
        await store.send(.startDuplicating) { $0.form = SnippetFormState(draft: copy, isNew: true) }
        await store.send(.formChanged(nil)) { $0.form = nil }
        #expect(store.state.items == [original])
        await store.send(.startEditing) { $0.form = SnippetFormState(draft: original, isNew: false) }
        #expect(!store.state.draftKeywordIsTaken)
        var edited = original
        edited.name = "Edited"
        await store.send(.formChanged(SnippetFormState(draft: edited, isNew: false))) {
            $0.form = SnippetFormState(draft: edited, isNew: false)
        }
        edited.modifiedAt = now
        await store.send(.saveDraft) {
            $0.items = [edited]
            $0.orderedResults = [edited]
            $0.form = nil
            $0.selectedID = original.id
        }
    }

    @Test func pinningAndDeletionKeepTheKeyboardOnTheNextVisibleSnippet() async {
        let first = Snippet(name: "First", text: "first")
        let second = Snippet(name: "Second", text: "second")
        let store = TestStore(initialState: SnippetFeature.State(items: [first, second])) { SnippetFeature() }
        await store.send(.selectionChanged(second.id)) { $0.selectedID = second.id }
        var pinned = second
        pinned.isPinned = true
        await store.send(.togglePin) {
            $0.items = [first, pinned]
            $0.orderedResults = [pinned, first]
            $0.pinnedCount = 1
        }
        await store.send(.deleteSelected) {
            $0.items = [first]
            $0.orderedResults = [first]
            $0.pinnedCount = 0
            $0.selectedID = first.id
        }
        await store.send(.deleteSelected) {
            $0.items = []
            $0.orderedResults = []
            $0.selectedID = nil
        }
        await store.send(.copySelected)
        await store.send(.pasteSelected)
        await store.send(.moveSelection(.max))
    }

    @Test func largeListJumpsAndPagingPreserveFiltersAndDrafts() async {
        let items = (0..<5_000).map { Snippet(name: "Entry \($0)", collection: "Work", text: "Body") }
        var state = SnippetFeature.State(items: items)
        state.query = "Entry"
        state.collectionFilter = "Work"
        state.form = SnippetFormState(draft: items[10], isNew: false)
        let store = TestStore(initialState: state) { SnippetFeature() }
        await store.send(.moveSelection(.max)) { $0.selectedID = items.last?.id }
        await store.send(.moveSelection(-1)) { $0.selectedID = items[4_998].id }
        await store.send(.moveSelection(.min)) { $0.selectedID = items.first?.id }
        await store.send(.moveSelection(10)) { $0.selectedID = items[10].id }
        await store.send(.resetPosition) { $0.selectedID = items.first?.id }
        let missingID = UUID()
        await store.send(.selectionChanged(missingID)) { $0.selectedID = missingID }
        await store.send(.moveSelection(1)) { $0.selectedID = items[1].id }
    }

    @Test func copyAndPasteCaptureTheRequestedSnippet() async {
        let first = Snippet(name: "First", text: "{argument:name}")
        let second = Snippet(name: "Second", text: "{clipboard}")
        let copied = LockIsolated<[Snippet]>([])
        let pasted = LockIsolated<[Snippet]>([])
        let store = TestStore(initialState: SnippetFeature.State(items: [first, second])) { SnippetFeature() } withDependencies: {
            $0.snippetClient.copy = { item in copied.withValue { $0.append(item) } }
            $0.snippetClient.paste = { item in pasted.withValue { $0.append(item) } }
        }
        await store.send(.copySelected)
        await store.send(.selectionChanged(second.id)) { $0.selectedID = second.id }
        await store.send(.pasteSelected)
        await store.send(.selectionChanged(first.id)) { $0.selectedID = first.id }
        await store.finish()
        #expect(copied.value == [first])
        #expect(pasted.value == [second])
    }

    @Test func usageRefreshReordersResultsWithoutLosingSelectionOrDraft() async {
        let first = Snippet(name: "First", text: "first")
        let second = Snippet(name: "Second", text: "second")
        var state = SnippetFeature.State(items: [first, second])
        state.selectedID = first.id
        state.form = SnippetFormState(draft: first, isNew: false)
        let store = TestStore(initialState: state) { SnippetFeature() }
        let usage = [second.id: Date(timeIntervalSince1970: 100)]
        await store.send(.dataChanged([first, second], lastUsed: usage)) {
            $0.lastUsed = usage
            $0.orderedResults = [second, first]
        }
        await store.send(.dataChanged([first, second], lastUsed: usage))
    }
}
