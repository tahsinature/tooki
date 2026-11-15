import ComposableArchitecture
import TookiKit

/// The feature requests work without knowing about NSPasteboard, windows, or storage.
@DependencyClient
public struct ClipboardClient: Sendable {
    public var copy: @Sendable (ClipboardItem) async -> Void
    public var paste: @Sendable (ClipboardItem) async -> Void
    public var togglePin: @Sendable (ClipboardItem) async -> Void
    public var remove: @Sendable (ClipboardItem) async -> Void
}

extension ClipboardClient: DependencyKey {
    public static let liveValue = ClipboardClient()
    public static let testValue = ClipboardClient()
}

extension DependencyValues {
    public var clipboardClient: ClipboardClient {
        get { self[ClipboardClient.self] }
        set { self[ClipboardClient.self] = newValue }
    }
}
