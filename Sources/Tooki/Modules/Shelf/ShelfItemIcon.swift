import AppKit
import QuickLookThumbnailing
import SwiftUI

/// The item's icon, or for a picture, a small preview of the picture itself.
struct ShelfItemIcon: View {
    let item: ShelfItem
    let size: CGFloat

    @State private var preview: NSImage?

    var body: some View {
        Group {
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
            } else {
                Image(nsImage: item.icon)
                    .resizable()
            }
        }
        .frame(width: size, height: size)
        // A copy still being made has no file yet, so try again once it's there.
        .task(id: "\(item.path) \(item.exists) \(item.conversionRevision?.uuidString ?? "")") {
            let image = await ShelfPreviews.image(of: item.url, size: size, revision: item.conversionRevision)
            guard !Task.isCancelled else { return }
            preview = image
        }
    }
}

@MainActor
private enum ShelfPreviews {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(of url: URL, size: CGFloat, revision: UUID?) async -> NSImage? {
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        guard type?.conforms(to: .image) == true else { return nil }
        let key = "\(url.path) \(size) \(revision?.uuidString ?? "")" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        let image: NSImage? = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                continuation.resume(returning: thumbnail?.nsImage)
            }
        }
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}
