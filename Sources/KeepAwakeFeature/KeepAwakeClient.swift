import ComposableArchitecture
import TookiKit

@DependencyClient
public struct KeepAwakeClient: Sendable {
    public var setAssertion: @Sendable (KeepAwakeMode?) async -> Bool = { _ in false }
}

extension KeepAwakeClient: DependencyKey {
    public static let liveValue = KeepAwakeClient()
    public static let testValue = KeepAwakeClient()
}

extension DependencyValues {
    public var keepAwakeClient: KeepAwakeClient {
        get { self[KeepAwakeClient.self] }
        set { self[KeepAwakeClient.self] = newValue }
    }
}
