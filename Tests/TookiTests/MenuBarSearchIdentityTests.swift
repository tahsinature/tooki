import AppKit
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func menuBarDuplicateTitlesKeepDistinctRowsAndNativeTargets() {
        _ = NSApplication.shared
        let source = [menuItem(window: 1, x: 20), menuItem(window: 2, x: 200), menuItem(window: 3, x: 300)]
        var pressed: [CGWindowID?] = []
        let rows = MenuBarSearchItemFactory.items(from: source.reversed(), boundary: 100) { pressed.append($0.windowID) }
        #expect(Set(rows.map(\.id)).count == 3)
        #expect(rows.map(\.kind) == ["Shown", "Shown", "Hidden"])
        #expect(rows.map(\.title) == ["Stats", "Stats", "Stats"])
        for row in rows { row.run() }
        #expect(pressed == [3, 2, 1])
        let refreshed = MenuBarSearchItemFactory.items(from: source, boundary: 100) { _ in }
        #expect(refreshed.map(\.id) == rows.map(\.id))
        let model = SearchModel(items: rows, placeholder: "Search", title: "Menu Bar", icon: .symbol("menubar.rectangle"), history: LaunchHistory())
        #expect(model.results.count == 3)
        #expect(Set(model.results.map(\.id)).count == 3)
    }

    @Test func duplicateAppleAccessibilityIdentifiersRemainDistinct() {
        let inputs = [MenuBarItemDescriptor(bundleID: "com.apple.controlcenter", identifier: "com.apple.menuextra.wifi", appName: "MenuBarAgent"),
                      MenuBarItemDescriptor(bundleID: "com.apple.controlcenter", identifier: "com.apple.menuextra.wifi", appName: "MenuBarAgent")]
        #expect(MenuBarLayoutPlanner.ids(for: inputs) == ["com.apple.menuextra.wifi", "com.apple.menuextra.wifi#2"])
    }

    private func menuItem(window: CGWindowID, x: CGFloat) -> MenuBarItem {
        MenuBarItem(element: nil, pid: -1, appName: "Stats", bundleID: "eu.exelban.Stats", identifier: nil,
                    label: "Stats", frame: CGRect(x: x, y: 0, width: 20, height: 22), windowID: window, eventPID: -1)
    }
}
