import Foundation
import Testing
@testable import TookiKit

struct PlaceholderExpanderTests {
    let noon = Date(timeIntervalSince1970: 1_793_793_600) // 2026-11-04 12:00 UTC

    @Test func expandsClipboardAndArguments() {
        let context = ExpansionContext(clipboard: "PR-42", arguments: ["name": "Ada"])
        let result = PlaceholderExpander.expand("Hi {argument:name}, see {clipboard}", context: context)
        #expect(result.text == "Hi Ada, see PR-42")
    }

    @Test func expandsDateWithCustomFormat() {
        let context = ExpansionContext(now: noon)
        let result = PlaceholderExpander.expand("{date:yyyy}", context: context)
        #expect(result.text == "2026")
    }

    @Test func cursorBecomesOffsetFromEnd() {
        let result = PlaceholderExpander.expand("<b>{cursor}</b>", context: ExpansionContext())
        #expect(result == ExpansionResult(text: "<b></b>", cursorOffsetFromEnd: 4))
    }

    @Test func leavesUnknownPlaceholdersUntouched() {
        let result = PlaceholderExpander.expand("{nope} {argument:missing}!", context: ExpansionContext())
        #expect(result.text == "{nope} !")
    }

    @Test func listsUniqueArgumentNamesInOrder() {
        let names = PlaceholderExpander.argumentNames(in: "{argument:b} {argument:a} {argument:b} {date}")
        #expect(names == ["b", "a"])
    }
}

struct KeywordMatcherTests {
    @Test func prefersLongestMatchingKeyword() {
        let short = Snippet(name: "a", keyword: "il", text: "")
        let long = Snippet(name: "b", keyword: ";mail", text: "")
        let empty = Snippet(name: "c", keyword: "", text: "")
        #expect(KeywordMatcher.match(typed: "send ;mail", in: [short, long, empty])?.name == "b")
        #expect(KeywordMatcher.match(typed: "hello", in: [short, long, empty]) == nil)
    }

    @Test func typedBufferKeepsOnlyRecentCharacters() {
        var buffer = TypedBuffer(maxLength: 3)
        buffer.append("abcd")
        buffer.deleteLast()
        #expect(buffer.text == "bc")
    }
}

struct ConfigTests {
    @Test func missingFieldsUseDefaults() throws {
        let json = #"{ "hyperKey": { "enabled": false }, "keepAwake": { "mode": "system" } }"#
        let config = try JSONDecoder().decode(TookiConfig.self, from: Data(json.utf8))
        #expect(!config.hyperKey.enabled)
        #expect(config.hyperKey.bindings == HyperKeyConfig().bindings)
        #expect(config.keepAwake.mode == .system)
        #expect(config.clipboard == ClipboardConfig())
    }

    @Test func wrongTypesAreReportedAsErrors() {
        let json = #"{ "clipboard": { "maxItems": "lots" } }"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TookiConfig.self, from: Data(json.utf8))
        }
    }

    @Test func parsesHotkeyActions() {
        #expect(HotkeyAction("open:com.apple.mail") == .open("com.apple.mail"))
        #expect(HotkeyAction("keepAwake.toggle") == .toggleKeepAwake)
        #expect(HotkeyAction("open:") == nil)
        #expect(HotkeyAction("explode") == nil)
    }
}

struct ClipboardLogTests {
    @Test func movesDuplicatesToTopAndTrims() {
        var log = ClipboardLog()
        log.record(ClipboardItem(text: "a"), maxItems: 2, maxImages: 2)
        log.record(ClipboardItem(text: "b"), maxItems: 2, maxImages: 2)
        log.record(ClipboardItem(text: "a"), maxItems: 2, maxImages: 2)
        log.record(ClipboardItem(text: "c"), maxItems: 2, maxImages: 2)
        #expect(log.items.map(\.text) == ["c", "a"])
    }

    @Test func limitsImagesSeparatelyAndDeduplicatesThem() {
        func image(_ name: String) -> ClipboardItem {
            ClipboardItem(image: ClipboardImage(fileName: name, width: 1, height: 1))
        }
        var log = ClipboardLog()
        log.record(image("1.png"), maxItems: 10, maxImages: 2)
        log.record(ClipboardItem(text: "a"), maxItems: 10, maxImages: 2)
        log.record(image("2.png"), maxItems: 10, maxImages: 2)
        log.record(image("1.png"), maxItems: 10, maxImages: 2)
        log.record(image("3.png"), maxItems: 10, maxImages: 2)
        #expect(log.items.map(\.title) == ["Image (1×1)", "Image (1×1)", "a"])
        #expect(log.imageFileNames == ["3.png", "1.png"])
    }

    @Test func storesRecognizedTextAndDecodesOldHistory() throws {
        var log = ClipboardLog()
        log.record(ClipboardItem(image: ClipboardImage(fileName: "x.png", width: 2, height: 2)), maxItems: 5, maxImages: 5)
        log.setRecognizedText("constitution", forImage: "x.png")
        #expect(log.items[0].image?.recognizedText == "constitution")

        let old = #"{"items":[{"id":"8B1D248E-A982-4CE4-AF51-AA88B46FFB5C","text":"hi","copiedAt":0}]}"#
        let decoded = try JSONDecoder().decode(ClipboardLog.self, from: Data(old.utf8))
        #expect(decoded.items[0].text == "hi" && decoded.items[0].image == nil)
        #expect(decoded.items[0].timesCopied == 1 && !decoded.items[0].isPinned)
    }

    @Test func copyingAgainKeepsPinCountAndFirstDate() {
        var log = ClipboardLog()
        let first = Date(timeIntervalSince1970: 100)
        log.record(ClipboardItem(text: "a", copiedAt: first), maxItems: 5, maxImages: 5)
        log.togglePin(id: log.items[0].id)
        log.record(ClipboardItem(text: "a"), maxItems: 5, maxImages: 5)
        #expect(log.items.count == 1)
        #expect(log.items[0].isPinned && log.items[0].timesCopied == 2 && log.items[0].firstCopiedAt == first)
    }

    @Test func pinnedItemsSurviveTrimming() {
        var log = ClipboardLog()
        log.record(ClipboardItem(text: "keep"), maxItems: 2, maxImages: 2)
        log.togglePin(id: log.items[0].id)
        for text in ["a", "b", "c"] {
            log.record(ClipboardItem(text: text), maxItems: 2, maxImages: 2)
        }
        #expect(log.items.map(\.text) == ["c", "b", "keep"])
    }

    @Test func detectsContentTypes() {
        #expect(ClipboardItem(text: "#FF6363").contentType == .color)
        #expect(ClipboardItem(text: "#abc").contentType == .color)
        #expect(ClipboardItem(text: "#GGGGGG").contentType == .text)
        #expect(ClipboardItem(text: "slack://channel?team=T1").contentType == .link)
        #expect(ClipboardItem(text: "https://a.com/b c").contentType == .text)
        #expect(ClipboardItem(text: "note:hello").contentType == .text)
        #expect(ClipboardItem(text: "a.txt", files: ["/tmp/a.txt"]).contentType == .file)
        #expect(HexColor("#FF0000")?.red == 1 && HexColor("#FF000080")?.alpha == 128.0 / 255)
    }
}

struct MenuBarLayoutPlannerTests {
    let separator = MenuBarLayoutPlanner.separatorID

    /// Applies moves the way the menu bar does until the planner is done, returning the result and move count.
    func arrange(_ start: [String], _ layout: MenuBarLayout) -> (bar: [String], moves: Int) {
        var bar = start
        var moves = 0
        while let move = MenuBarLayoutPlanner.nextMove(current: bar, layout: layout), moves < 50 {
            bar.removeAll { $0 == move.item }
            switch move.placement {
            case .before(let anchor): bar.insert(move.item, at: bar.firstIndex(of: anchor)!)
            case .after(let anchor): bar.insert(move.item, at: bar.firstIndex(of: anchor)! + 1)
            }
            moves += 1
        }
        return (bar, moves)
    }

    @Test func reachesLayoutWithFewestMoves() {
        let layout = MenuBarLayout(shown: ["b", "c", "d"], hidden: ["a"])
        let result = arrange(["d", "a", separator, "b", "c"], layout)
        #expect(result.bar == ["a", separator, "b", "c", "d"])
        #expect(result.moves == 1)
    }

    @Test func movesIconsAcrossTheSeparator() {
        let layout = MenuBarLayout(shown: ["a"], hidden: ["b", "c"])
        #expect(arrange(["a", "b", separator, "c"], layout).bar == ["b", "c", separator, "a"])
    }

    @Test func skipsMissingAppsAndLeavesUnknownIconsAlone() {
        let layout = MenuBarLayout(shown: ["b", "notInstalled", "a"], hidden: [])
        let result = arrange(["new", separator, "a", "b"], layout)
        #expect(result.bar == ["new", separator, "b", "a"])
        #expect(result.moves == 1)
    }

    @Test func doesNothingWhenAlreadyArranged() {
        let layout = MenuBarLayout(shown: ["a", "b"], hidden: ["c"])
        #expect(MenuBarLayoutPlanner.nextMove(current: ["c", separator, "a", "b"], layout: layout) == nil)
    }

    @Test func keepsTheToggleRightOfTheSeparator() {
        let toggle = MenuBarLayoutPlanner.toggleID
        let layout = MenuBarLayout(shown: ["b"], hidden: ["a"])
        #expect(arrange([toggle, "a", separator, "b"], layout).bar == ["a", separator, toggle, "b"])
    }

    @Test func numbersAdditionalIconsOfTheSameApp() {
        let ids = MenuBarLayoutPlanner.ids(for: [
            MenuBarItemDescriptor(bundleID: "eu.exelban.Stats", identifier: nil, appName: "Stats"),
            MenuBarItemDescriptor(bundleID: "com.apple.controlcenter", identifier: "com.apple.menuextra.wifi", appName: "Control Center"),
            MenuBarItemDescriptor(bundleID: "eu.exelban.Stats", identifier: nil, appName: "Stats"),
        ])
        #expect(ids == ["eu.exelban.Stats", "com.apple.menuextra.wifi", "eu.exelban.Stats#2"])
    }
}
