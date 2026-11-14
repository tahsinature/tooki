import SwiftUI
import Testing
@testable import Tooki

@MainActor
struct PanelKeyboardNavigationTests {
    @Test func pageKeysAndCommandArrowsHaveDistinctMovement() {
        #expect(PanelKeyboardNavigation.offset(for: .upArrow, pageSize: 7) == -1)
        #expect(PanelKeyboardNavigation.offset(for: .downArrow, pageSize: 7) == 1)
        #expect(PanelKeyboardNavigation.offset(for: .pageUp, pageSize: 7) == -7)
        #expect(PanelKeyboardNavigation.offset(for: .pageDown, pageSize: 7) == 7)
        #expect(PanelKeyboardNavigation.offset(for: .upArrow, modifiers: .command, pageSize: 7) == -Int.max / 2)
        #expect(PanelKeyboardNavigation.offset(for: .downArrow, modifiers: .command, pageSize: 7) == Int.max / 2)
        #expect(PanelKeyboardNavigation.offset(for: .home, pageSize: 7) == -Int.max / 2)
        #expect(PanelKeyboardNavigation.offset(for: .end, pageSize: 7) == Int.max / 2)
    }

    @Test func gridMovementUsesRowsAndViewportPageSize() {
        #expect(PanelKeyboardNavigation.offset(for: .downArrow, pageSize: 60, stride: 10) == 10)
        #expect(PanelKeyboardNavigation.offset(for: .pageDown, pageSize: 60, stride: 10) == 60)
        #expect(PanelKeyboardNavigation.offset(for: .downArrow, modifiers: .command, pageSize: 60, stride: 10) == Int.max / 2)
    }

    @Test func popupMovementDoesNotScrollTheResultsBehindIt() {
        let navigation = PanelKeyboardNavigation()
        navigation.setPageSize(9, in: .results)
        navigation.setPageSize(5, in: .actions)
        navigation.moved(in: .actions)
        #expect(navigation.revision(in: .results) == 0)
        #expect(navigation.revision(in: .actions) == 1)
        #expect(navigation.resultsPageSize == 9)
        #expect(navigation.actionsPageSize == 5)
        navigation.moved(in: .actions)
        #expect(navigation.revision(in: .actions) == 2)
    }
}
