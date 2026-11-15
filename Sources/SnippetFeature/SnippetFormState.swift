import TookiKit

/// A draft is independent of saved snippets until the user saves it.
public struct SnippetFormState: Equatable, Sendable {
    public var draft: Snippet
    public let isNew: Bool

    public init(draft: Snippet, isNew: Bool) {
        self.draft = draft
        self.isNew = isNew
    }
}
