import Foundation

/// Immutable input metadata. The native client retains the exact ShelfItem for commit validation.
public struct ShelfConversionItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let ownsFile: Bool

    public init(id: UUID, url: URL, name: String, ownsFile: Bool) {
        self.id = id
        self.url = url
        self.name = name
        self.ownsFile = ownsFile
    }
}
