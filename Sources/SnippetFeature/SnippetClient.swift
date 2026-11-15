import ComposableArchitecture
import TookiKit

/// Native placeholder expansion, usage recording and insertion stay in the application.
@DependencyClient
public struct SnippetClient: Sendable {
    public var copy: @Sendable (Snippet) async -> Void
    public var paste: @Sendable (Snippet) async -> Void
}

extension SnippetClient: DependencyKey {
    public static let liveValue = SnippetClient()
    public static let testValue = SnippetClient()
}

extension DependencyValues {
    public var snippetClient: SnippetClient {
        get { self[SnippetClient.self] }
        set { self[SnippetClient.self] = newValue }
    }
}
