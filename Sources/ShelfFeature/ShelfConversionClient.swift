import ComposableArchitecture
import Foundation
import TookiKit

@DependencyClient
public struct ShelfConversionClient: Sendable {
    public var validate: @Sendable ([ShelfConversionItem]) async throws -> Void
    public var prepare: @Sendable (ShelfConversionItem, ImageConversionOptions) async throws -> ImageConversionPreview
    public var details: @Sendable (ImageConversionPreview) async throws -> ImagePreviewDetails
    public var save: @Sendable (ShelfConversionResult, ImageConversionOptions.Output) async throws -> UUID
    public var discard: @Sendable (ImageConversionPreview) async -> Void
    public var didSave: @Sendable ([UUID]) async -> Void
    public var dismissPreview: @Sendable () async -> Void
    public var close: @Sendable () async -> Void
}

extension ShelfConversionClient: DependencyKey {
    public static let liveValue = ShelfConversionClient()
    public static let testValue = ShelfConversionClient()
}

extension DependencyValues {
    public var shelfConversionClient: ShelfConversionClient {
        get { self[ShelfConversionClient.self] }
        set { self[ShelfConversionClient.self] = newValue }
    }
}
