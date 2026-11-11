import Foundation

/// Decides cheaply whether a launcher query could be a calculation, so plain
/// words, URLs and paths never produce junk results.
public enum InputGate {
    private static let naturalLanguagePrefixes = [
        "time", "days", "weeks", "months", "next ", "this ", "today", "tomorrow", "yesterday",
        "ratio", "sqrt", "cbrt", "diff ", "christmas", "new year", "halloween", "valentine",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "rgb(", "hsl(", "half of", "square root", "cube root", "increase ", "decrease ", "% change",
    ]

    public static func shouldAttempt(_ query: String) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 256, !looksLikeURLOrPath(text) else { return false }
        if text.contains(where: \.isASCIIDigit) || text.hasPrefix("#") {
            return true
        }
        let lower = text.lowercased()
        if lower.hasSuffix(" time") || isPi(lower) {
            return true
        }
        return naturalLanguagePrefixes.contains { lower.hasPrefix($0) }
    }

    /// `pi`, `pi/2`, but not `pizza`.
    private static func isPi(_ lower: String) -> Bool {
        guard lower.hasPrefix("pi") else { return false }
        guard let thirdByte = lower.utf8.dropFirst(2).first else { return true }
        let isLowercaseLetter = (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(thirdByte)
        return !isLowercaseLetter
    }

    static func looksLikeURLOrPath(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("://") || lower.hasPrefix("www.") || lower.hasPrefix("~/") || lower.hasPrefix("~\\") {
            return true
        }
        if text.hasPrefix("/") && text.dropFirst().contains("/") {
            return true
        }
        if text.contains(where: \.isWhitespace) {
            return false
        }
        let host = hostRemovingPort(String(text.prefix { $0 != "/" && $0 != "?" && $0 != "#" }))
        if host.lowercased() == "localhost" || isIPv4Literal(host) {
            return true
        }
        let beforeSlash = text.prefix { $0 != "/" }
        guard let dot = beforeSlash.lastIndex(of: ".") else { return false }
        let topLevelLabel = beforeSlash[beforeSlash.index(after: dot)...]
        return topLevelLabel.count >= 2 && topLevelLabel.allSatisfy(\.isASCIILetter)
    }

    /// `example.com:8080` → `example.com`.
    private static func hostRemovingPort(_ authority: String) -> String {
        guard let colon = authority.lastIndex(of: ":") else { return authority }
        let port = authority[authority.index(after: colon)...]
        guard !port.isEmpty, port.count <= 5, port.allSatisfy(\.isASCIIDigit) else { return authority }
        return String(authority[..<colon])
    }

    private static func isIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { !$0.isEmpty && $0.count <= 3 && $0.allSatisfy(\.isASCIIDigit) }
    }
}
