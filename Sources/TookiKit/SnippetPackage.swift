import Foundation

public struct SnippetPackageIdentity: Codable, Equatable, Sendable {
    public var identifier: String
    public var version: String
    public var author: String
    public init(identifier: String, version: String, author: String) {
        self.identifier = identifier; self.version = version; self.author = author
    }
}

/// Portable gallery format. Personal configuration, local identity and pin/usage state stay local.
public struct SnippetPackage: Codable, Equatable, Identifiable, Sendable {
    public var formatVersion = 1
    public var identity: SnippetPackageIdentity
    public var name: String
    public var description: String
    public var suggestedKeyword: String
    public var text: String
    public var dynamic: DynamicSnippet?
    public var capabilities: [String] = []
    public var id: String { identity.identifier }

    public init(identity: SnippetPackageIdentity, name: String, description: String, suggestedKeyword: String, text: String = "", dynamic: DynamicSnippet? = nil) {
        self.identity = identity; self.name = name; self.description = description
        self.suggestedKeyword = suggestedKeyword; self.text = text; self.dynamic = dynamic
    }

    public init(exporting snippet: Snippet, author: String, description: String) {
        self.init(identity: snippet.package ?? SnippetPackageIdentity(identifier: snippet.id.uuidString.lowercased(), version: "1.0.0", author: author),
                  name: snippet.name, description: description, suggestedKeyword: snippet.keyword, text: snippet.text, dynamic: snippet.dynamic)
        // Defaults for configuration fields are also personal data. Never share saved setup values.
        if dynamic != nil {
            for index in dynamic!.settings.indices { dynamic!.settings[index].defaultValue = "" }
        }
    }

    public func validate() throws {
        guard formatVersion == 1 else { throw SnippetDefinitionError("This package needs a newer version of Tooki.") }
        guard capabilities.isEmpty else { throw SnippetDefinitionError("This version supports snippets without external capabilities only.") }
        guard !identity.identifier.isEmpty, !identity.version.isEmpty, !name.isEmpty else { throw SnippetDefinitionError("The package is missing its identity, version or name.") }
        guard text.utf8.count + (dynamic?.script.utf8.count ?? 0) < 200_000 else { throw SnippetDefinitionError("This snippet is too large.") }
        if let dynamic { try dynamic.validate() }
        else if text.isEmpty { throw SnippetDefinitionError("The snippet has no content.") }
    }

    /// Used only after review. Existing local preferences survive an update.
    public func installing(over existing: Snippet?, keyword: String, configuration: [String: String]) throws -> Snippet {
        try validate()
        if let dynamic { _ = try dynamic.values(configuration, for: dynamic.settings) }
        return Snippet(id: existing?.id ?? UUID(), name: name, keyword: keyword,
                       collection: existing?.collection ?? "Gallery", text: text, dynamic: dynamic,
                       configuration: configuration, package: identity, isPinned: existing?.isPinned ?? false,
                       createdAt: existing?.createdAt ?? Date(), modifiedAt: Date())
    }
}
