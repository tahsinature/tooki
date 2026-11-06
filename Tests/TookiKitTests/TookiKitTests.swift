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
        #expect(config.shortcuts == Shortcut.defaults)
        #expect(config.keepAwake.mode == .system)
        #expect(config.clipboard == ClipboardConfig())
        #expect(config.shelf == ShelfConfig())
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

    @Test func movesOldHyperKeyBindingsToShortcuts() throws {
        let json = #"{ "hyperKey": { "bindings": [{ "key": "m", "action": "open:com.apple.mail" }] } }"#
        let config = try JSONDecoder().decode(TookiConfig.self, from: Data(json.utf8))
        #expect(config.shortcuts == [Shortcut(action: "open:com.apple.mail", keys: "hyper+m")])
    }
}

struct KeyComboTests {
    @Test func parsesAndWritesConfigText() {
        #expect(KeyCombo("hyper+s")?.modifiers == .hyper)
        #expect(KeyCombo("Cmd+Option+K")?.description == "opt+cmd+k")
        #expect(KeyCombo("ctrl+opt+shift+cmd+,")?.description == "hyper+,")
        #expect(KeyCombo("hyper+,")?.symbols == ["⌃", "⌥", "⇧", "⌘", ","])
    }

    @Test func rejectsUnknownKeysAndBareKeys() {
        #expect(KeyCombo("hyper+") == nil)
        #expect(KeyCombo("meta+s") == nil)
        #expect(KeyCombo("s") == nil)
        #expect(KeyCombo("f5")?.key == "f5")
    }

    @Test func flagsCommonSystemShortcuts() {
        #expect(KeyCombo("cmd+c")?.isReservedBySystem == true)
        #expect(KeyCombo("hyper+c")?.isReservedBySystem == false)
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

    @Test func reportsCopiedFilesThatNoLongerExist() throws {
        let existing = FileManager.default.temporaryDirectory.appending(path: "tooki-\(UUID()).txt")
        try Data().write(to: existing)
        defer { try? FileManager.default.removeItem(at: existing) }
        let deleted = "/tmp/tooki-deleted-\(UUID()).txt"

        let item = ClipboardItem(text: "files", files: [existing.path, deleted])
        #expect(item.missingFiles == [deleted])
        #expect(ClipboardItem(text: "plain").missingFiles.isEmpty)
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

    @Test func describesColors() {
        #expect(HexColor("#3F3F3F")?.rgbDescription == "rgb(63, 63, 63)")
        #expect(HexColor("#3F3F3F")?.hslDescription == "hsl(0, 0%, 25%)")
        #expect(HexColor("#FF6363")?.hslDescription == "hsl(0, 100%, 69%)")
        #expect(HexColor("#0A84FF")?.hslDescription == "hsl(210, 100%, 52%)")
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

struct SkhdConfigTests {
    @Test func readsModifiersHexKeysAndCommands() {
        let bindings = SkhdConfig.parse("""
        # comment
        alt + shift - t : hs -c 'toggle("Alacritty")'
        shift + cmd - 0x12 : open shottr://grab
        hyper - k : echo hi
        """)
        #expect(bindings == [
            SkhdConfig.Binding(combo: KeyCombo("opt+shift+t")!, command: "hs -c 'toggle(\"Alacritty\")'"),
            SkhdConfig.Binding(combo: KeyCombo("shift+cmd+1")!, command: "open shottr://grab"),
            SkhdConfig.Binding(combo: KeyCombo("hyper+k")!, command: "echo hi"),
        ])
    }

    @Test func skipsContinuationLinesAndUnsupportedHotkeys() {
        let bindings = SkhdConfig.parse("""
        alt - a : echo one \\
            && echo two: still the same command
        fn - b : echo fn
        alt - c : echo three
        """)
        #expect(bindings.map(\.combo) == [KeyCombo("opt+a")!, KeyCombo("opt+c")!])
    }
}

struct SystemShortcutsTests {
    @Test func usesDefaultsUnlessChangedOrDisabled() {
        let entries = SystemShortcuts.parse([
            // Spotlight moved to ⌥Space; Finder search turned off.
            "64": ["enabled": true, "value": ["parameters": [32, 49, 524288]]],
            "65": ["enabled": false],
        ])
        let byName = Dictionary(entries.map { ($0.name, $0.combo) }, uniquingKeysWith: { first, _ in first })
        #expect(byName["Show Spotlight search"] == KeyCombo("opt+space"))
        #expect(byName["Show Finder search window"] == nil)
        #expect(byName["Mission Control"] == KeyCombo("ctrl+up"))
    }
}

struct TookiURLCommandTests {
    private func command(_ text: String) -> TookiURLCommand? {
        URL(string: text).flatMap(TookiURLCommand.init)
    }

    @Test func addsEveryDecodedPathToTheShelf() {
        let url = "tooki://shelf/add?path=/Users/me/My%20Report.pdf&path=~/a+b.txt&path="
        #expect(command(url) == .shelf(.add(paths: ["/Users/me/My Report.pdf", "~/a+b.txt"], asCopies: false, shelf: nil)))
    }

    @Test func addsCopiesOnlyWithCopyMode() {
        #expect(command("tooki://shelf/add?path=/a&mode=copy") == .shelf(.add(paths: ["/a"], asCopies: true, shelf: nil)))
        #expect(command("tooki://shelf/add?path=/a&mode=original") == .shelf(.add(paths: ["/a"], asCopies: false, shelf: nil)))
        #expect(command("tooki://shelf/add?path=/a&mode=move") == nil)
    }

    @Test func parsesShelfVerbs() {
        #expect(command("tooki://shelf/toggle") == .shelf(.toggle(shelf: nil)))
        #expect(command("TOOKI://shelf/clear/") == .shelf(.clear(shelf: nil)))
        #expect(command("tooki://shelf/new") == .shelf(.new))
        #expect(command("tooki://shelf/add") == nil)
        #expect(command("tooki://shelf/explode") == nil)
    }

    @Test func picksAShelfByNameOrNew() {
        #expect(command("tooki://shelf/add?path=/a&shelf=Work%20stuff") == .shelf(.add(paths: ["/a"], asCopies: false, shelf: "Work stuff")))
        #expect(command("tooki://shelf/add?path=/a&shelf=new&mode=copy") == .shelf(.add(paths: ["/a"], asCopies: true, shelf: "new")))
        #expect(command("tooki://shelf/clear?shelf=") == .shelf(.clear(shelf: nil)))
        #expect(command("tooki://shelf/show?shelf=Shelf%202") == .shelf(.show(shelf: "Shelf 2")))
    }

    @Test func runsOnlyBuiltInActions() {
        #expect(command("tooki://run/clipboard") == .run(.clipboard))
        #expect(command("tooki://run/open:com.apple.Terminal") == nil)
        #expect(command("https://shelf/show") == nil)
    }
}

struct AppVersionTests {
    @Test func comparesNumberByNumber() {
        #expect(AppVersion.isNewer("v0.10.0", than: "0.9.5"))
        #expect(AppVersion.isNewer("1.0", than: "0.99.99"))
        #expect(!AppVersion.isNewer("v0.6.0", than: "0.6.0"))
        #expect(!AppVersion.isNewer("0.6", than: "0.6.0"))
        #expect(!AppVersion.isNewer("0.5.9", than: "0.6.0"))
    }
}
