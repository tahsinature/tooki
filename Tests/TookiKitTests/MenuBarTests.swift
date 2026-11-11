import CoreGraphics
import Foundation
import Testing
@testable import TookiKit

extension MenuBarLayoutPlannerTests {
    @Test func arrangesTheAlwaysHiddenSection() {
        let alwaysHiddenSeparator = MenuBarLayoutPlanner.alwaysHiddenSeparatorID
        let layout = MenuBarLayout(shown: ["c"], hidden: ["b"], alwaysHidden: ["a"])
        let result = arrange(["b", alwaysHiddenSeparator, "a", separator, "c"], layout)
        #expect(result.bar == ["a", alwaysHiddenSeparator, "b", separator, "c"])
    }

    @Test func arrangesAlwaysHiddenIconsWithoutTheirDivider() {
        let layout = MenuBarLayout(shown: ["c"], hidden: ["b"], alwaysHidden: ["a"])
        #expect(arrange(["c", separator, "b", "a"], layout).bar == ["a", "b", separator, "c"])
    }
}

struct MenuBarConfigTests {
    @Test func oldConfigsGetTheNewDefaults() throws {
        let json = #"{"enabled": true, "layout": {"shown": ["a"], "hidden": ["b"]}}"#
        let config = try JSONDecoder().decode(MenuBarConfig.self, from: Data(json.utf8))
        #expect(config.enabled)
        #expect(config.layout == MenuBarLayout(shown: ["a"], hidden: ["b"], alwaysHidden: []))
        #expect(!config.alwaysHiddenSection && !config.useThawBar && !config.showOnHover)
        #expect(config.dividerStyle == .line)
        #expect(config.tint == MenuBarTint())
    }

    @Test func tintColorRoundTripsThroughHex() {
        #expect(RGBColor(hex: "#1E90FF")?.hex == "#1E90FF")
        #expect(RGBColor(hex: "1e90ff")?.hex == "#1E90FF")
        #expect(RGBColor(hex: "#12345") == nil)
    }
}

struct MenuBarSectionTests {
    @Test func classifiesIconsByDivider() {
        func section(_ midX: CGFloat) -> MenuBarSection {
            MenuBarSection.of(midX: midX, hiddenDividerX: 500, alwaysHiddenDividerX: 300)
        }
        #expect(section(100) == .alwaysHidden)
        #expect(section(400) == .hidden)
        #expect(section(600) == .shown)
        #expect(MenuBarSection.of(midX: 100, hiddenDividerX: 500, alwaysHiddenDividerX: nil) == .hidden)
    }

    @Test func showingHiddenIconsKeepsAlwaysHiddenOnesAway() {
        #expect(MenuBarReveal.hidden.collapses(.alwaysHidden))
        #expect(!MenuBarReveal.hidden.collapses(.hidden))
        #expect(MenuBarReveal.nothing.collapses(.hidden))
        #expect(!MenuBarReveal.all.collapses(.alwaysHidden))
        #expect(MenuBarReveal.nothing.reveals(.shown))
    }

    @Test func pairsWindowsWithIconsByCenter() {
        let icon = CGRect(x: 100, y: 0, width: 24, height: 24)
        let windows = [CGRect(x: 50, y: 0, width: 24, height: 24), CGRect(x: 100.5, y: 0, width: 24, height: 24)]
        #expect(MenuBarFrameMatcher.index(matching: icon, in: windows) == 1)
        #expect(MenuBarFrameMatcher.index(matching: icon, in: [windows[0]]) == nil)
    }
}

struct MenuBarTriggerTests {
    let menuBar = CGRect(x: 0, y: 0, width: 1000, height: 24)

    func isEmpty(_ x: CGFloat, notch: CGRect? = nil) -> Bool {
        MenuBarTriggerZone.isEmptySpace(
            CGPoint(x: x, y: 10), menuBar: menuBar, appMenuMaxX: 200, notch: notch,
            itemFrames: [CGRect(x: 900, y: 0, width: 30, height: 24)]
        )
    }

    @Test func findsEmptyMenuBarSpace() {
        #expect(isEmpty(500))
        #expect(!isEmpty(150), "app menus")
        #expect(!isEmpty(910), "an icon")
        #expect(!isEmpty(500, notch: CGRect(x: 450, y: 0, width: 100, height: 24)))
        #expect(!MenuBarTriggerZone.isEmptySpace(CGPoint(x: 500, y: 40), menuBar: menuBar, appMenuMaxX: nil, notch: nil, itemFrames: []))
    }

    @Test func ignoresSmallScrolls() {
        #expect(MenuBarTriggerZone.scrollReveals(deltaX: 0, deltaY: 20) == true)
        #expect(MenuBarTriggerZone.scrollReveals(deltaX: 0, deltaY: -20) == false)
        #expect(MenuBarTriggerZone.scrollReveals(deltaX: 2, deltaY: 3) == nil)
    }

    @Test func keepsTheThawBarOnScreen() {
        func x(_ location: ThawBarLocation, mouseX: CGFloat) -> CGFloat {
            ThawBarPlacement.x(for: location, width: 200, screenMinX: 0, screenMaxX: 1000, mouseX: mouseX, dividerX: 600)
        }
        #expect(x(.underMouse, mouseX: 500) == 400)
        #expect(x(.underMouse, mouseX: 10) == 8)
        #expect(x(.underMouse, mouseX: 990) == 792)
        #expect(x(.underDivider, mouseX: 0) == 500)
        #expect(x(.rightAligned, mouseX: 0) == 792)
    }
}
