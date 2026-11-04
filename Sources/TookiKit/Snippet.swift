import Foundation

public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Typing this anywhere replaces it with the snippet. Empty disables expansion.
    public var keyword: String
    public var collection: String
    public var text: String

    public init(id: UUID = UUID(), name: String, keyword: String = "", collection: String = "", text: String) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.collection = collection
        self.text = text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        name = try container.decode(.name, default: "Untitled")
        keyword = try container.decode(.keyword, default: "")
        collection = try container.decode(.collection, default: "")
        text = try container.decode(.text, default: "")
    }

    public static let examples = [
        Snippet(name: "Today", keyword: ";date", collection: "General", text: "{date}"),
        Snippet(name: "Shrug", keyword: ";shrug", collection: "General", text: #"¯\_(ツ)_/¯"#),
        Snippet(
            name: "Email reply",
            keyword: ";thanks",
            collection: "Work",
            text: "Hi {argument:name},\n\nThanks for reaching out. {cursor}\n\nBest,\nMohammad"
        ),
    ]
}

public enum KeywordMatcher {
    /// Returns the snippet whose keyword the typed text ends with, preferring the longest keyword.
    public static func match(typed: String, in snippets: [Snippet]) -> Snippet? {
        snippets
            .filter { !$0.keyword.isEmpty && typed.hasSuffix($0.keyword) }
            .max { $0.keyword.count < $1.keyword.count }
    }
}

/// Remembers the most recent characters the user typed.
public struct TypedBuffer: Sendable {
    public private(set) var text = ""
    private let maxLength: Int

    public init(maxLength: Int = 64) {
        self.maxLength = maxLength
    }

    public mutating func append(_ characters: String) {
        text += characters
        if text.count > maxLength {
            text = String(text.suffix(maxLength))
        }
    }

    public mutating func deleteLast() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset() {
        text = ""
    }
}
