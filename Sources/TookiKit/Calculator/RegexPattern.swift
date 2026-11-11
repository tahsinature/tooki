import Foundation

/// A regular expression compiled once and kept in a static constant, so
/// typing in the launcher never recompiles a pattern.
struct RegexPattern: Sendable {
    private let regex: NSRegularExpression

    init(_ pattern: String) {
        // Every pattern is a literal in this module, so a typo is a programmer error.
        regex = try! NSRegularExpression(pattern: pattern)
    }

    func firstMatch(in text: String) -> RegexMatch? {
        let nsText = text as NSString
        return regex.firstMatch(in: text, range: Self.fullRange(of: nsText)).map { RegexMatch($0, in: nsText) }
    }

    func matches(_ text: String) -> Bool {
        firstMatch(in: text) != nil
    }

    /// Replaces every match using an ICU template such as `"$1^$2"`.
    func replacingAll(in text: String, template: String) -> String {
        regex.stringByReplacingMatches(in: text, range: Self.fullRange(of: text as NSString), withTemplate: template)
    }

    /// Replaces the first match only, using an ICU template.
    func replacingFirst(in text: String, template: String) -> String {
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: Self.fullRange(of: nsText)) else { return text }
        let replacement = regex.replacementString(for: match, in: text, offset: 0, template: template)
        return nsText.replacingCharacters(in: match.range, with: replacement)
    }

    /// Replaces every match with whatever `replacement` returns for it.
    func replacingAll(in text: String, with replacement: (RegexMatch) -> String) -> String {
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: Self.fullRange(of: nsText))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        for match in matches {
            result += nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += replacement(RegexMatch(match, in: nsText))
            cursor = match.range.location + match.range.length
        }
        return result + nsText.substring(from: cursor)
    }

    private static func fullRange(of text: NSString) -> NSRange {
        NSRange(location: 0, length: text.length)
    }
}

/// The capture groups of one match. Group 0 is the whole match; a group
/// that did not take part in the match is `nil`.
struct RegexMatch {
    let groups: [String?]

    fileprivate init(_ result: NSTextCheckingResult, in text: NSString) {
        groups = (0..<result.numberOfRanges).map { index in
            let range = result.range(at: index)
            return range.location == NSNotFound ? nil : text.substring(with: range)
        }
    }

    /// The text of group `index`, or `nil` when it did not take part in the match.
    subscript(index: Int) -> String? {
        index < groups.count ? groups[index] : nil
    }

    /// The text of group `index`, or an empty string when it did not take part.
    func text(_ index: Int) -> String {
        self[index] ?? ""
    }
}
