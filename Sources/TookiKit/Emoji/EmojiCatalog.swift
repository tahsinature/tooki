import Foundation

public struct Emoji: Identifiable, Equatable, Sendable {
    public let character: String
    /// Lowercase CLDR name, e.g. "grinning face".
    public let name: String
    /// Display name of the group it belongs to, e.g. "Smileys & Emotion".
    public let group: String
    /// Extra search words, e.g. "like" and "yes" for 👍.
    public let keywords: [String]
    /// GitHub-style codes, e.g. "+1" and "thumbsup" for 👍.
    public let shortcodes: [String]

    public var id: String { character }
    /// The code to type between colons to expand it, e.g. `:grinning:`.
    public var shortcode: String { shortcodes.first ?? nameCode }
    /// The name with underscores, e.g. "grinning_face". Also accepted as a shortcode.
    var nameCode: String { name.replacingOccurrences(of: " ", with: "_") }
}

/// Every emoji this Mac can draw, from the emojibase data bundled in `EmojiData.swift`.
/// Run `scripts/update-emoji.py` to pick up new emoji.
public enum EmojiCatalog {
    public static let all: [Emoji] = EmojiAvailability.drawable(parse(data))

    /// Group names in display order, skipping groups with nothing to show.
    public static let groups: [String] = groupNames.filter { name in all.contains { $0.group == name } }

    /// Best match first. Name matches outrank keyword and shortcode matches.
    public static func search(_ query: String, in emoji: [Emoji] = all) -> [Emoji] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return emoji }
        return emoji
            .compactMap { item in score(query, for: item).map { (item, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    public static func emoji(forShortcode shortcode: String) -> Emoji? {
        shortcodeIndex[shortcode.lowercased()]
    }

    /// The emoji whose `:shortcode:` the typed text ends with, and how many characters that code is.
    public static func shortcodeMatch(typed: String) -> (emoji: Emoji, length: Int)? {
        guard typed.hasSuffix(":") else { return nil }
        let body = typed.dropLast().reversed().prefix { $0.isLetter || $0.isNumber || "_+-".contains($0) }
        let code = String(body.reversed())
        guard code.count >= 2, typed.dropLast(code.count + 1).hasSuffix(":"),
              let emoji = emoji(forShortcode: code) else { return nil }
        return (emoji, code.count + 2)
    }

    private static func score(_ query: String, for emoji: Emoji) -> Double? {
        let nameScore = FuzzyMatch.score(query, in: emoji.name)
        // Keywords and shortcodes rank a little below a name match of the same kind.
        let otherScores = (emoji.keywords + emoji.shortcodes).compactMap { FuzzyMatch.score(query, in: $0) }
        let best = max(nameScore ?? 0, (otherScores.max() ?? 0) - 5)
        return best >= 55 ? best : nil
    }

    private static let shortcodeIndex: [String: Emoji] = {
        var index: [String: Emoji] = [:]
        for emoji in all {
            for code in emoji.shortcodes + [emoji.nameCode] where index[code] == nil {
                index[code] = emoji
            }
        }
        return index
    }()

    private static func parse(_ text: String) -> [Emoji] {
        text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 5, let groupIndex = Int(fields[2]), groupNames.indices.contains(groupIndex) else {
                return nil
            }
            return Emoji(
                character: fields[0],
                name: fields[1],
                group: groupNames[groupIndex],
                keywords: list(fields[3]),
                shortcodes: list(fields[4])
            )
        }
    }

    private static func list(_ field: String) -> [String] {
        field.split(separator: ",").map(String.init)
    }
}
