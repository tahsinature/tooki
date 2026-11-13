import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct ConversionPreviewImage: View {
    let url: URL
    let revision: UUID
    @ViewState private var image: NSImage?
    @ViewState private var didLoad = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if didLoad {
                Label("Preview unavailable", systemImage: "eye.slash").font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Image preview")
        .task(id: "\(url.path) \(revision)") {
            image = nil
            didLoad = false
            let data = await Task.detached(priority: .userInitiated) { thumbnail(url) }.value
            guard !Task.isCancelled else { return }
            image = data.flatMap(NSImage.init(data:))
            didLoad = true
        }
    }

    private nonisolated func thumbnail(_ url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 560,
              ] as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let writer = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(writer, image, nil)
        return CGImageDestinationFinalize(writer) ? data as Data : nil
    }
}
