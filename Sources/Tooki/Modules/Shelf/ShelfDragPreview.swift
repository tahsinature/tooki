import AppKit
import ImageIO
import SwiftUI

/// Uses the same drag card as Clipboard History, with one card for the whole selection.
@MainActor
enum ShelfDragPreview {
    static func image(for items: [ShelfItem], appearance: NSAppearance) -> NSImage {
        guard let first = items.first else { return NSImage() }
        let thumbnail = thumbnail(for: first)
        let detail = items.count == 1 ? first.shortDetail : "\(items.count.formatted()) items"
        let card = DragPreviewCard(title: first.name, detail: detail) {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        return card.image(appearance: appearance) ?? first.icon
    }

    private static func thumbnail(for item: ShelfItem) -> NSImage {
        // Decode only a small thumbnail, even for large photos. Other files use their Finder icon.
        guard let source = CGImageSourceCreateWithURL(item.url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 80,
              ] as CFDictionary)
        else { return item.icon }
        return NSImage(cgImage: image, size: .zero)
    }
}
