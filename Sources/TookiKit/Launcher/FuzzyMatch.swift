import Foundation

/// Scores how well a search query matches a title, the way launchers rank results.
/// Higher is better; `nil` means no match. Stronger kinds of match always outrank weaker ones.
public enum FuzzyMatch {
    public static func score(_ query: String, in title: String) -> Double? {
        let query = normalized(query)
        let title = normalized(title)
        guard !query.isEmpty else { return 0 }
        if title == query { return 100 }
        if title.hasPrefix(query) { return 90 }
        let words = title.split(whereSeparator: isSeparator)
        if words.contains(where: { $0.hasPrefix(query) }) { return 80 }
        if String(words.compactMap(\.first)).hasPrefix(query) { return 70 }
        if title.contains(query) { return 60 }
        // Scattered letters only mean something in short names; in long text they match almost anything.
        if title.count <= 40, isSubsequence(query, of: title) { return 30 }
        return nil
    }

    /// Lowercased and without accents, so "cafe" finds "Café".
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == " " || character == "-" || character == "_" || character == "."
    }

    /// Every query character appears in the title, in order: "gchr" in "google chrome".
    private static func isSubsequence(_ query: String, of title: String) -> Bool {
        var remaining = query[...]
        for character in title where character == remaining.first {
            remaining.removeFirst()
            if remaining.isEmpty { return true }
        }
        return false
    }
}
