import Foundation
import TookiKit

public struct ShelfConversionResult: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let item: ShelfConversionItem
    public let preview: ImageConversionPreview
    public var details: ImagePreviewDetails
    public var error: String?
    public var wasOpened = false
    public var revision: UUID

    public init(id: UUID, item: ShelfConversionItem, preview: ImageConversionPreview,
                details: ImagePreviewDetails, revision: UUID) {
        self.id = id
        self.item = item
        self.preview = preview
        self.details = details
        self.revision = revision
    }
}
