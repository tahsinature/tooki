import Foundation

public struct DynamicKeywordMatch: Sendable {
    public let snippet: Snippet
    public let inputs: [String: String]
    public let length: Int
}

public enum DynamicKeywordMatcher {
    /// Matches only a completed token at a word boundary. A bare prefix never expands.
    public static func match(typed: String, in snippets: [Snippet]) -> DynamicKeywordMatch? {
        for snippet in snippets.sorted(by: { $0.keyword.count > $1.keyword.count }) {
            guard let dynamic = snippet.dynamic, !snippet.keyword.isEmpty,
                  typed.last == dynamic.completion.character else { continue }
            let body = typed.dropLast()
            guard let range = body.range(of: snippet.keyword, options: .backwards) else { continue }
            if range.lowerBound != body.startIndex {
                let previous = body[body.index(before: range.lowerBound)]
                guard !previous.isLetter && !previous.isNumber && previous != "_" && previous != "@" else { continue }
            }
            let arguments = body[range.upperBound...].trimmingCharacters(in: .whitespaces)
            guard let parts = parseArguments(arguments), parts.count <= dynamic.inputs.count,
                  dynamic.inputs.isEmpty || !parts.isEmpty else { continue }
            let supplied = Dictionary(uniqueKeysWithValues: zip(dynamic.inputs.map(\.key), parts))
            guard let inputs = try? dynamic.values(supplied, for: dynamic.inputs) else { continue }
            if dynamic.engine == .lookup, dynamic.lookup(inputs: inputs, config: snippet.configuration) == nil { continue }
            return DynamicKeywordMatch(snippet: snippet, inputs: inputs, length: typed[range.lowerBound...].count)
        }
        return nil
    }

    /// Quoted arguments allow spaces with a semicolon completion, without shell interpretation.
    public static func parseArguments(_ text: String) -> [String]? {
        var parts: [String] = []; var current = ""; var quoted = false; var escaped = false; var started = false
        for character in text {
            if escaped { current.append(character); escaped = false; started = true }
            else if character == "\\" { escaped = true }
            else if character == "\"" { quoted.toggle(); started = true }
            else if character.isWhitespace && !quoted {
                if started { parts.append(current); current = ""; started = false }
            } else { current.append(character); started = true }
        }
        guard !quoted && !escaped else { return nil }
        if started { parts.append(current) }
        return parts
    }
}
