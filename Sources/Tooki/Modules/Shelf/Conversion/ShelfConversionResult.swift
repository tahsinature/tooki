import Foundation
import TookiKit

struct ShelfConversionResult: Identifiable, Sendable {
    let id = UUID()
    let item: ShelfItem
    let preview: ImageConversionPreview
    var details: ImagePreviewDetails
    var error: String?
    var wasOpened = false
    var revision = UUID()
}
