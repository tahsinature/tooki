import Foundation
import Testing
@testable import TookiKit

struct FuzzyMatchTests {
    @Test func strongerMatchesRankHigher() throws {
        let exact = try #require(FuzzyMatch.score("safari", in: "Safari"))
        let prefix = try #require(FuzzyMatch.score("saf", in: "Safari"))
        let word = try #require(FuzzyMatch.score("studio", in: "Visual Studio Code"))
        let initials = try #require(FuzzyMatch.score("vsc", in: "Visual Studio Code"))
        let contains = try #require(FuzzyMatch.score("fari", in: "Safari"))
        let subsequence = try #require(FuzzyMatch.score("gchr", in: "Google Chrome"))
        #expect(exact > prefix && prefix > word && word > initials && initials > contains && contains > subsequence)
    }

    @Test func ignoresCaseAndAccents() {
        #expect(FuzzyMatch.score("CAFE", in: "Café") == 100)
    }

    @Test func returnsNilWithoutMatch() {
        #expect(FuzzyMatch.score("xyz", in: "Safari") == nil)
        #expect(FuzzyMatch.score("ifas", in: "Safari") == nil)
    }
}

struct LaunchHistoryTests {
    @Test func frequentAndRecentPicksGetBiggerBoost() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var history = LaunchHistory()
        history.record("old", at: now.addingTimeInterval(-60 * 86_400))
        history.record("often", at: now)
        history.record("often", at: now)
        history.record("once", at: now)
        #expect(history.boost(for: "often", now: now) > history.boost(for: "once", now: now))
        #expect(history.boost(for: "once", now: now) > history.boost(for: "old", now: now))
        #expect(history.boost(for: "never", now: now) == 0)
        #expect(history.recentIDs(limit: 2, now: now) == ["often", "once"])
    }

    @Test func boostIsCapped() {
        var history = LaunchHistory()
        for _ in 0..<50 { history.record("app") }
        #expect(history.boost(for: "app") == 20)
    }
}

struct EmojiCatalogTests {
    @Test func loadsBundledEmojiData() throws {
        let grinning = try #require(EmojiCatalog.all.first { $0.character == "😀" })
        #expect(grinning.name == "grinning face")
        #expect(grinning.shortcode == "grinning")
        #expect(grinning.group == "Smileys & Emotion")
        #expect(EmojiCatalog.all.contains { $0.character == "🇨🇦" && $0.name == "flag: canada" })
        #expect(EmojiCatalog.all.contains { $0.character == "👨‍👩‍👧" })
        #expect(!EmojiCatalog.all.contains { $0.character == "🏻" })
        #expect(EmojiCatalog.groups.first == "Smileys & Emotion")
    }

    @Test func searchRanksNameStartFirst() {
        let results = EmojiCatalog.search("rocket")
        #expect(results.first?.character == "🚀")
        #expect(EmojiCatalog.search("zzzqqq").isEmpty)
    }

    @Test func searchFindsKeywords() {
        #expect(EmojiCatalog.search("like").contains { $0.character == "👍" })
    }

    @Test func findsByShortcode() {
        #expect(EmojiCatalog.emoji(forShortcode: "thumbsup")?.character == "👍")
        #expect(EmojiCatalog.emoji(forShortcode: "grinning_face")?.character == "😀")
        #expect(EmojiCatalog.shortcodeMatch(typed: "ok :+1:")?.emoji.character == "👍")
        let match = EmojiCatalog.shortcodeMatch(typed: "nice :rocket:")
        #expect(match?.emoji.character == "🚀" && match?.length == 8)
        #expect(EmojiCatalog.shortcodeMatch(typed: "rocket:") == nil)
        #expect(EmojiCatalog.shortcodeMatch(typed: ":nothing_here:") == nil)
    }
}
