import ComposableArchitecture
import Foundation
import Testing
import TookiKit
@testable import ClipboardFeature

@MainActor
struct ClipboardFeatureTests {
    @Test func unchangedQueryKeepsSelectionAndFilteringUsesSourceNames() async {
        let first = ClipboardItem(text: "Hello", sourceApp: "example.editor")
        let second = ClipboardItem(text: "Other")
        let store = TestStore(initialState: ClipboardFeature.State(items: [first, second], sourceNames: ["example.editor": "Editor"])) {
            ClipboardFeature()
        }
        await store.send(.selectionChanged(second.id)) { $0.selectedID = second.id }
        await store.send(.queryChanged(""))
        await store.send(.queryChanged("editor")) {
            $0.query = "editor"
            $0.selectedID = nil
            $0.orderedResults = [first]
        }
    }

    @Test func pinningKeepsSelectionAndDeletionSelectsNeighbour() async {
        let first = ClipboardItem(text: "First")
        let second = ClipboardItem(text: "Second")
        let mutations = LockIsolated<[String]>([])
        let store = TestStore(initialState: ClipboardFeature.State(items: [first, second])) {
            ClipboardFeature()
        } withDependencies: {
            $0.clipboardClient.togglePin = { item in mutations.withValue { $0.append("pin:\(item.id)") } }
            $0.clipboardClient.remove = { item in mutations.withValue { $0.append("remove:\(item.id)") } }
        }
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
        await store.finish()
        #expect(Set(mutations.value) == Set(["pin:\(second.id)", "remove:\(second.id)"]))
    }

    @Test func pasteWaitsForFocusAndCapturesTheSelectedItem() async {
        let clock = TestClock()
        let first = ClipboardItem(text: "First")
        let second = ClipboardItem(text: "Second")
        let pasted = LockIsolated<[ClipboardItem]>([])
        let store = TestStore(initialState: ClipboardFeature.State(items: [first, second])) {
            ClipboardFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.clipboardClient.paste = { item in pasted.withValue { $0.append(item) } }
        }
        await store.send(.pasteSelected)
        await store.send(.selectionChanged(second.id)) { $0.selectedID = second.id }
        #expect(pasted.value.isEmpty)
        await clock.advance(by: .milliseconds(80))
        await store.finish()
        #expect(pasted.value == [first])
    }

    @Test func keyboardJumpsAndPositionResetPreserveTheFilter() async {
        let items = (0..<1000).map { ClipboardItem(text: "Entry \($0)") }
        let store = TestStore(initialState: ClipboardFeature.State(items: items)) { ClipboardFeature() }
        await store.send(.moveSelection(Int.max)) { $0.selectedID = items.last?.id }
        await store.send(.moveSelection(Int.min)) { $0.selectedID = items.first?.id }
        await store.send(.queryChanged("Entry")) { $0.query = "Entry"; $0.selectedID = nil }
        await store.send(.moveSelection(25)) { $0.selectedID = items[25].id }
        await store.send(.resetPosition) { $0.selectedID = items.first?.id }
    }

    @Test func recognizedTextRefreshesFilteredHistoryAndCopyUsesTheVisibleItem() async {
        let image = ClipboardItem(image: ClipboardImage(fileName: "image.png", width: 10, height: 10))
        let copied = LockIsolated<[ClipboardItem]>([])
        let store = TestStore(initialState: ClipboardFeature.State(items: [image])) {
            ClipboardFeature()
        } withDependencies: {
            $0.clipboardClient.copy = { item in copied.withValue { $0.append(item) } }
        }
        await store.send(.queryChanged("invoice")) {
            $0.query = "invoice"
            $0.orderedResults = []
        }
        await store.send(.typeFilterChanged(.image)) { $0.typeFilter = .image }
        var recognized = image
        recognized.image?.recognizedText = "Invoice for project"
        await store.send(.historyChanged([recognized], sourceNames: [:])) {
            $0.items = [recognized]
            $0.orderedResults = [recognized]
        }
        await store.send(.copySelected)
        await store.finish()
        #expect(copied.value == [recognized])
        await store.send(.historyChanged([], sourceNames: [:])) {
            $0.items = []
            $0.orderedResults = []
        }
        await store.send(.copySelected)
        #expect(copied.value.count == 1)
    }

    @Test func navigationFromTheBottomAndStaleSelectionUsesVisiblePositions() async {
        let items = (0..<5_000).map { ClipboardItem(text: "Entry \($0)") }
        let store = TestStore(initialState: ClipboardFeature.State(items: items)) { ClipboardFeature() }
        await store.send(.selectionChanged(items.last!.id)) { $0.selectedID = items.last!.id }
        await store.send(.moveSelection(-1)) { $0.selectedID = items[4_998].id }
        let missingID = ClipboardItem(text: "Removed").id
        await store.send(.selectionChanged(missingID)) { $0.selectedID = missingID }
        await store.send(.moveSelection(1)) { $0.selectedID = items[1].id }
        await store.send(.selectionChanged(nil)) { $0.selectedID = nil }
        await store.send(.moveSelection(-1)) { $0.selectedID = items.first!.id }
    }
}
