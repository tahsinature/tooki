import Foundation

public struct ExpansionContext: Sendable {
    public var now: Date
    public var clipboard: String
    public var arguments: [String: String]

    public init(now: Date = Date(), clipboard: String = "", arguments: [String: String] = [:]) {
        self.now = now
        self.clipboard = clipboard
        self.arguments = arguments
    }
}

public struct ExpansionResult: Equatable, Sendable {
    public var text: String
    /// How many characters the cursor should move left after pasting (for `{cursor}`).
    public var cursorOffsetFromEnd: Int
}

/// Replaces snippet placeholders:
/// `{date}`, `{date:FORMAT}`, `{time}`, `{time:FORMAT}`, `{clipboard}`, `{cursor}`, `{argument:name}`.
/// Unknown placeholders are left untouched.
public enum PlaceholderExpander {
    private nonisolated(unsafe) static let pattern = /\{([a-zA-Z]+)(?::([^}]*))?\}/

    public static func argumentNames(in template: String) -> [String] {
        var names: [String] = []
        for match in template.matches(of: pattern) where match.1 == "argument" {
            if let name = match.2.map(String.init), !name.isEmpty, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    public static func expand(_ template: String, context: ExpansionContext) -> ExpansionResult {
        var output = ""
        var cursorPosition: Int?
        var remaining = template[...]

        while let match = remaining.firstMatch(of: pattern) {
            output += remaining[..<match.range.lowerBound]
            let name = String(match.1)
            let option = match.2.map(String.init)

            if name == "cursor" {
                if cursorPosition == nil { cursorPosition = output.count }
            } else {
                output += value(for: name, option: option, context: context) ?? String(match.0)
            }
            remaining = remaining[match.range.upperBound...]
        }
        output += remaining

        let offset = cursorPosition.map { output.count - $0 } ?? 0
        return ExpansionResult(text: output, cursorOffsetFromEnd: offset)
    }

    private static func value(for name: String, option: String?, context: ExpansionContext) -> String? {
        switch name {
        case "date": format(context.now, option ?? "yyyy-MM-dd")
        case "time": format(context.now, option ?? "HH:mm")
        case "clipboard": context.clipboard
        case "argument": option.flatMap { context.arguments[$0] } ?? ""
        default: nil
        }
    }

    private static func format(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
