import Foundation

/// How the user writes numbers. The pipeline rewrites queries into the
/// canonical `1,234.56` notation on the way in and back on the way out.
public enum NumberFormat: String, Sendable, Codable, CaseIterable {
    /// `1,234.56`: point decimal, comma grouping.
    case point
    /// `1.234,56`: comma decimal, point grouping.
    case comma

    /// Regions whose CLDR decimal separator is a comma. Deliberate
    /// exclusions: `CH`/`LI` and the point-decimal Spanish-speaking regions.
    static let commaDecimalRegions: Set<String> = [
        "AD", "AL", "AM", "AO", "AR", "AT", "AX", "AZ", "BA", "BE", "BF", "BG", "BI", "BJ", "BO", "BR",
        "BY", "CD", "CF", "CG", "CI", "CL", "CM", "CO", "CR", "CU", "CV", "CY", "CZ", "DE", "DK", "DZ",
        "EC", "EE", "ES", "FI", "FO", "FR", "GA", "GE", "GF", "GL", "GN", "GP", "GQ", "GR", "GW", "HR",
        "HT", "HU", "ID", "IS", "IT", "KG", "KZ", "LT", "LU", "LV", "MA", "MC", "MD", "ME", "MK", "ML",
        "MN", "MQ", "MZ", "NC", "NE", "NL", "NO", "PF", "PL", "PT", "PY", "RE", "RO", "RS", "RU", "RW",
        "SE", "SI", "SK", "SM", "SN", "SR", "ST", "TD", "TG", "TJ", "TM", "TN", "TR", "UA", "UY", "UZ",
        "VA", "VE", "VN", "ZA",
    ]

    /// Languages that write comma-decimal wherever they are spoken. Only
    /// consulted when the locale carries no region, since the region decides.
    static let commaDecimalLanguages: Set<String> = [
        "af", "az", "be", "bg", "bs", "ca", "cs", "da", "de", "el", "es", "et", "eu", "fi", "fr", "gl",
        "hr", "hu", "hy", "id", "is", "it", "ka", "kk", "ky", "lt", "lv", "mk", "mn", "nb", "nl", "nn",
        "no", "pl", "pt", "ro", "ru", "sk", "sl", "sq", "sr", "sv", "tr", "uk", "uz", "vi",
    ]

    static func forLanguage(_ language: String, region: String?) -> NumberFormat {
        guard let region else {
            return commaDecimalLanguages.contains(language) ? .comma : .point
        }
        // Canada is split down the language line: fr-CA writes `1 234,56`.
        if region == "CA" {
            return language == "fr" ? .comma : .point
        }
        return commaDecimalRegions.contains(region) ? .comma : .point
    }

    /// The format implied by a locale tag such as `de-DE`, `en_DE` or `fr`.
    public static func fromLocaleTag(_ tag: String) -> NumberFormat {
        let withoutKeywords = tag.split(separator: "@").first.map(String.init) ?? tag
        let parts = withoutKeywords.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        let language = (parts.first ?? "en").lowercased()
        let region = parts.dropFirst().first { $0.count == 2 && $0.allSatisfy(\.isASCIILetter) }?.uppercased()
        return forLanguage(language, region: region)
    }

    /// The format a macOS locale is configured for.
    public static func detect(locale: Locale = .current) -> NumberFormat {
        fromLocaleTag(locale.identifier)
    }

    /// Parses a stored preference. `"auto"` and anything unknown mean
    /// "follow the locale", returned as `nil`.
    public static func fromPreference(_ value: String) -> NumberFormat? {
        NumberFormat(rawValue: value.trimmingCharacters(in: .whitespaces).lowercased())
    }
}

/// Rewrites numbers between the user's notation and the canonical one.
enum NumberNotation {
    private static let groupedThousands = RegexPattern(#"\b\d{1,3}(?:\.\d{3})+,\d+\b|\b\d{1,3}(?:\.\d{3}){2,}\b"#)

    /// Rewrites a query written in `format` into canonical `1,234.56`.
    ///
    /// A lone `1.234` stays a decimal on purpose (`3.14 * 2` must not become
    /// `314 * 2`). Grouping is only honored when unambiguous: two or more
    /// groups (`1.234.567`) or a comma decimal behind it (`1.234,56`).
    static func canonicalize(_ query: String, from format: NumberFormat) -> String {
        if format == .point || isColorFunction(query) {
            return query
        }
        let ungrouped = groupedThousands.replacingAll(in: query) { match in
            match.text(0).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        // Any remaining comma between two digits is a decimal mark.
        return swappingSeparatorsBetweenDigits(ungrouped) { $0 == "," ? "." : $0 }
    }

    /// Rewrites a canonical answer into `format`. Only separators between two
    /// digits are swapped, so list commas (`rgb(255, 0, 0)`) survive.
    static func localize(_ text: String, to format: NumberFormat) -> String {
        if format == .point {
            return text
        }
        return swappingSeparatorsBetweenDigits(text) { character in
            switch character {
            case ",": "."
            case ".": ","
            default: character
            }
        }
    }

    /// Color functions are the one place where a comma between digits is a
    /// list separator, not a decimal mark: `rgb(255,0,0)`.
    private static func isColorFunction(_ query: String) -> Bool {
        let lower = query.lowercased()
        return ["rgb(", "rgba(", "hsl(", "hsla("].contains { lower.contains($0) }
    }

    private static func swappingSeparatorsBetweenDigits(_ text: String, _ swap: (Character) -> Character) -> String {
        let characters = Array(text)
        var result = ""
        for (index, character) in characters.enumerated() {
            let isBetweenDigits = index > 0 && characters[index - 1].isASCIIDigit
                && index + 1 < characters.count && characters[index + 1].isASCIIDigit
            result.append(isBetweenDigits ? swap(character) : character)
        }
        return result
    }
}
