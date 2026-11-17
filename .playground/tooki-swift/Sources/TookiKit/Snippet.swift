import Foundation

public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Typing this anywhere replaces it with the snippet. Empty disables expansion.
    public var keyword: String
    public var collection: String
    public var text: String
    public var isPinned: Bool
    /// `nil` for snippets written by hand or saved before Tooki tracked dates.
    public var createdAt: Date?
    public var modifiedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, keyword, collection, text, isPinned, createdAt, modifiedAt
    }

    public init(
        id: UUID = UUID(),
        name: String,
        keyword: String = "",
        collection: String = "",
        text: String,
        isPinned: Bool = false,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.collection = collection
        self.text = text
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(.id, default: UUID())
        name = try container.decode(.name, default: "Untitled")
        keyword = try container.decode(.keyword, default: "")
        collection = try container.decode(.collection, default: "")
        text = try container.decode(.text, default: "")
        isPinned = try container.decode(.isPinned, default: false)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }

    /// Leaves out `isPinned` when false and missing dates, so hand-written files stay short.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keyword, forKey: .keyword)
        try container.encode(collection, forKey: .collection)
        try container.encode(text, forKey: .text)
        if isPinned { try container.encode(isPinned, forKey: .isPinned) }
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(modifiedAt, forKey: .modifiedAt)
    }

    /// Whether every word of the query appears in the name, keyword, collection or text.
    public func matches(_ query: String) -> Bool {
        let words = query.lowercased().split(separator: " ")
        guard !words.isEmpty else { return true }
        let haystack = "\(name) \(keyword) \(collection) \(text)".lowercased()
        return words.allSatisfy { haystack.contains($0) }
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
