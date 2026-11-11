import Foundation

public struct Emoji: Identifiable, Equatable, Sendable {
    public let character: String
    /// Lowercase Unicode name, e.g. "grinning face".
    public let name: String
    public let category: EmojiCategory

    public var id: String { character }
    /// Typed between colons to expand it, e.g. `:grinning_face:`.
    public var shortcode: String { name.replacingOccurrences(of: " ", with: "_") }
}

/// Groups follow the Unicode blocks emoji live in, so no data file has to ship with the app.
public enum EmojiCategory: String, CaseIterable, Sendable {
    case smileys = "Smileys & People"
    case people = "People & Body"
    case nature = "Nature & Objects"
    case travel = "Travel & Places"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"

    static func of(_ value: UInt32) -> EmojiCategory {
        switch value {
        case 0x1F600...0x1F64F: .smileys
        case 0x1F900...0x1F9FF: .people
        case 0x1F300...0x1F5FF: .nature
        case 0x1F680...0x1F6FF: .travel
        case 0x1FA70...0x1FAFF: .objects
        default: .symbols
        }
    }
}

/// Every single-character emoji macOS can draw, plus country flags, built from Unicode data.
public enum EmojiCatalog {
    public static let all: [Emoji] = scalars() + flags()

    /// Name matches first: whole name, start of the name, start of a word, then anywhere.
    public static func search(_ query: String, in emoji: [Emoji] = all) -> [Emoji] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return emoji }
        return emoji
            .compactMap { item in FuzzyMatch.score(query, in: item.name).flatMap { $0 >= 60 ? (item, $0) : nil } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    public static func emoji(forShortcode shortcode: String) -> Emoji? {
        all.first { $0.shortcode == shortcode.lowercased() }
    }

    /// The emoji whose `:shortcode:` the typed text ends with, and how many characters that code is.
    public static func shortcodeMatch(typed: String) -> (emoji: Emoji, length: Int)? {
        guard typed.hasSuffix(":") else { return nil }
        let body = typed.dropLast().reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        let code = String(body.reversed())
        guard code.count >= 2, typed.dropLast(code.count + 1).hasSuffix(":"),
              let emoji = emoji(forShortcode: code) else { return nil }
        return (emoji, code.count + 2)
    }

    private static let ranges: [ClosedRange<UInt32>] = [
        0x2100...0x27BF, 0x2B00...0x2BFF, 0x1F000...0x1F2FF, 0x1F300...0x1FAFF,
    ]

    private static func scalars() -> [Emoji] {
        ranges.flatMap { $0 }.compactMap { value in
            guard let scalar = Unicode.Scalar(value), isStandaloneEmoji(scalar), let name = scalar.properties.name else {
                return nil
            }
            // Text-style symbols such as ❤ need the emoji variation selector to draw in color.
            let character = scalar.properties.isEmojiPresentation ? String(scalar) : String(scalar) + "\u{FE0F}"
            return Emoji(character: character, name: name.lowercased(), category: .of(value))
        }
    }

    private static func isStandaloneEmoji(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        guard properties.isEmoji, !properties.isEmojiModifier else { return false }
        let isRegionalIndicator = (0x1F1E6...0x1F1FF).contains(scalar.value)
        return !isRegionalIndicator && (properties.isEmojiPresentation || scalar.value >= 0x2190)
    }

    private static func flags() -> [Emoji] {
        let english = Locale(identifier: "en")
        return Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            guard code.count == 2, code.allSatisfy(\.isUppercase),
                  let name = english.localizedString(forRegionCode: code) else { return nil }
            let character = code.unicodeScalars
                .compactMap { Unicode.Scalar(0x1F1E6 + $0.value - 0x41) }
                .map(String.init)
                .joined()
            return Emoji(character: character, name: "flag \(name.lowercased())", category: .flags)
        }
        .sorted { $0.name < $1.name }
    }
}
