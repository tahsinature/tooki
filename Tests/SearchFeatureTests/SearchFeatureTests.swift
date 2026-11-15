import ComposableArchitecture
import Foundation
import SearchFeature
import Testing
import TookiKit

@MainActor
struct SearchFeatureTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let actions = [SearchActionMetadata(id: "run", title: "Open"), SearchActionMetadata(id: "copy", title: "Copy"),
                           SearchActionMetadata(id: "reveal", title: "Show in Finder")]

    private func entry(_ id: String, title: String? = nil, group: SearchGroup = .commands) -> SearchEntry {
        SearchEntry(id: id, title: title ?? id, group: group, actions: actions)
    }

    private func store(_ items: [SearchEntry], history: LaunchHistory = LaunchHistory()) -> TestStore<SearchFeature.State, SearchFeature.Action> {
        let store = TestStore(initialState: SearchFeature.State(items: items, history: history, now: now)) { SearchFeature() }
        // Assert observable behavior rather than repeating every derived result in expected state.
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    @Test func browsingPromotesRecentEntriesWithoutDuplicatingGroups() async {
        let app = entry("app", group: .applications)
        let command = entry("command")
        let menu = entry("menu", group: .menuBar)
        var history = LaunchHistory()
        history.record(command.id, at: now)
        history.record("removed", at: now)
        let store = store([app, command, menu], history: history)
        #expect(store.state.sections.map(\.title) == ["Recent", "Applications", "Menu Bar Items"])
        #expect(store.state.results.map(\.id) == ["command", "app", "menu"])
        await store.send(.groupFilterChanged(.applications, calculation: nil, at: now))
        #expect(store.state.results == [app])
        #expect(store.state.sections.map(\.title) == ["Applications"])
    }

    @Test func rankingRetainsFuzzyKeywordTextAndHistoryMatching() async {
        let first = entry("first", title: "Calculator")
        let used = entry("used", title: "Calibrate")
        let keyword = SearchEntry(id: "keyword", title: "Unrelated", keyword: ";calculate")
        let text = SearchEntry(id: "text", title: "Other", searchText: "needle haystack")
        var history = LaunchHistory()
        history.record(used.id, at: now)
        let store = store([first, used, keyword, text], history: history)
        await store.send(.queryChanged("ca", calculation: nil, at: now))
        #expect(store.state.results.first?.id == used.id)
        await store.send(.queryChanged(";cal", calculation: nil, at: now))
        #expect(store.state.results.map(\.id) == [keyword.id])
        await store.send(.queryChanged("needle haystack", calculation: nil, at: now))
        #expect(store.state.results.map(\.id) == [text.id])
    }

    @Test func calculatorAppearsBeforeMatchesOnlyInUnfilteredSearch() async {
        let match = entry("command", title: "2 + 2")
        let answer = entry("calculator", title: "4", group: .calculator)
        let store = store([match])
        await store.send(.queryChanged("2 + 2", calculation: answer, at: now))
        #expect(store.state.sections.map(\.title) == ["Calculator", "Results"])
        #expect(store.state.results.map(\.id) == [answer.id, match.id])
        await store.send(.groupFilterChanged(.commands, calculation: answer, at: now))
        #expect(store.state.results == [match])
        await store.send(.groupFilterChanged(nil, calculation: answer, at: now))
        #expect(store.state.results.first == answer)
        await store.send(.queryChanged("", calculation: nil, at: now))
        #expect(store.state.results == [match])
    }

    @Test func unchangedCommitsPreserveSelectionAndMenuState() async {
        let store = store([entry("first"), entry("second")])
        await store.send(.selectionChanged(1))
        await store.send(.actionsPresented(true))
        await store.send(.actionSelectionChanged(1))
        await store.send(.queryChanged("", calculation: nil, at: now))
        await store.send(.groupFilterChanged(nil, calculation: nil, at: now))
        await store.send(.menuQueryChanged(""))
        #expect(store.state.selection == 1)
        #expect(store.state.actionSelection == 1)
        #expect(store.state.isShowingActions)
        await store.send(.menuQueryChanged("copy"))
        #expect(store.state.menuActions.map(\.id) == ["copy"])
        #expect(store.state.actionSelection == 0)
        await store.send(.queryChanged("first", calculation: nil, at: now))
        #expect(!store.state.isShowingActions)
        #expect(store.state.menuQuery.isEmpty)
        #expect(store.state.selectedItem?.id == "first")
    }

    @Test func refreshPreservesIdentityFilterAndOpenMenuWhileReplacingMetadata() async {
        let store = store([entry("first"), entry("second")])
        await store.send(.groupFilterChanged(.commands, calculation: nil, at: now))
        await store.send(.selectionChanged(1))
        await store.send(.actionsPresented(true))
        await store.send(.menuQueryChanged("copy"))
        let updated = entry("second", title: "Updated")
        await store.send(.refreshed([entry("new"), updated], history: LaunchHistory(), calculation: nil, at: now))
        #expect(store.state.selectedItem == updated)
        #expect(store.state.groupFilter == .commands)
        #expect(store.state.isShowingActions)
        #expect(store.state.menuQuery == "copy")
        #expect(store.state.menuActions.map(\.id) == ["copy"])
        await store.send(.refreshed([entry("new")], history: LaunchHistory(), calculation: nil, at: now))
        #expect(store.state.selectedItem?.id == "new")
        await store.send(.refreshed([], history: LaunchHistory(), calculation: nil, at: now))
        #expect(store.state.selectedItem == nil)
        #expect(store.state.menuActions.isEmpty)
    }

    @Test func largeListAndActionNavigationBoundOffsetsAndKeepFilters() async {
        let items = (0..<5_000).map { entry("Entry \($0)") }
        let store = store(items)
        await store.send(.queryChanged("Entry", calculation: nil, at: now))
        await store.send(.groupFilterChanged(.commands, calculation: nil, at: now))
        await store.send(.moveSelection(.max))
        #expect(store.state.selectedItem?.id == items.last?.id)
        await store.send(.moveSelection(.min))
        #expect(store.state.selection == 0)
        await store.send(.moveSelection(10))
        #expect(store.state.selection == 10)
        await store.send(.actionsPresented(true))
        await store.send(.moveActionSelection(.max))
        #expect(store.state.actionSelection == 2)
        await store.send(.moveActionSelection(.min))
        #expect(store.state.actionSelection == 0)
        await store.send(.resetPosition)
        #expect(store.state.selection == 0)
        #expect(store.state.query == "Entry")
        #expect(store.state.groupFilter == .commands)
        await store.send(.menuQueryChanged("missing action"))
        await store.send(.moveActionSelection(.max))
        #expect(store.state.menuActions.isEmpty)
        #expect(store.state.actionSelection == 0)
    }
}
