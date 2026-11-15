import ComposableArchitecture
import EmojiFeature
import Testing
import TookiKit

@MainActor
struct EmojiFeatureTests {
    @Test func recentsKeepTheirOwnSectionAndSearchResetsSelection() async {
        let emoji = EmojiCatalog.all[0]
        let store = TestStore(initialState: EmojiFeature.State(recentCharacters: [emoji.character, "invalid"])) { EmojiFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        #expect(store.state.sections.first?.title == "Recently Used")
        #expect(store.state.results.filter { $0 == emoji }.count == 2)
        await store.send(.moveSelection(Int.max))
        #expect(store.state.selection == store.state.results.count - 1)
        await store.send(.actionsPresented(true))
        await store.send(.queryChanged("grinning"))
        #expect(store.state.selection == 0)
        #expect(!store.state.isShowingActions)
        #expect(store.state.sections.map(\.title) == ["Results"])
        #expect(store.state.results == EmojiCatalog.search("grinning"))
    }

    @Test func navigationHandlesExtremeOffsetsAndEmptyResults() async {
        let store = TestStore(initialState: EmojiFeature.State(recentCharacters: [])) { EmojiFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.moveSelection(Int.max))
        await store.send(.moveSelection(Int.min))
        #expect(store.state.selection == 0)
        await store.send(.moveActionSelection(Int.max))
        #expect(store.state.actionSelection == 2)
        await store.send(.moveActionSelection(Int.min))
        #expect(store.state.actionSelection == 0)
        await store.send(.queryChanged("no-such-emoji-284739"))
        await store.send(.moveSelection(Int.max))
        #expect(store.state.selected == nil)
        #expect(store.state.selection == 0)
    }

    @Test func unchangedQueryPreservesActionPopupAndPosition() async {
        let store = TestStore(initialState: EmojiFeature.State(recentCharacters: [])) { EmojiFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.selectionChanged(5))
        await store.send(.actionsPresented(true))
        await store.send(.queryChanged(""))
        #expect(store.state.selection == 5)
        #expect(store.state.isShowingActions)
    }
}
