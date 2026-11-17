import ComposableArchitecture
import EmojiFeature
import Testing

@MainActor
struct EmojiActionSearchTests {
    @Test func typingFiltersActionsAndSelectsTheMatchingCommand() async {
        let store = TestStore(initialState: EmojiFeature.State(recentCharacters: [])) { EmojiFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.actionsPresented(true))
        await store.send(.actionQueryChanged("paste"))
        #expect(store.state.visibleActions == [.paste])
        #expect(store.state.selectedAction == .paste)
        await store.send(.moveActionSelection(Int.max))
        #expect(store.state.actionSelection == 0)
        #expect(store.state.query.isEmpty)
        await store.send(.actionQueryChanged("copy shortcode"))
        #expect(store.state.selectedAction == .copyShortcode)
    }

    @Test func emptyMatchesCannotRunAndReopeningClearsTheFilter() async {
        let store = TestStore(initialState: EmojiFeature.State(recentCharacters: [])) { EmojiFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.actionsPresented(true))
        await store.send(.moveActionSelection(Int.max))
        await store.send(.actionQueryChanged("no such action"))
        #expect(store.state.selectedAction == nil)
        await store.send(.moveActionSelection(Int.min))
        #expect(store.state.actionSelection == 0)
        await store.send(.actionsPresented(false))
        await store.send(.actionsPresented(true))
        #expect(store.state.actionQuery.isEmpty)
        #expect(store.state.visibleActions == EmojiCommand.allCases)
        #expect(store.state.selectedAction == .copy)
    }
}
