import AppKit
import CryptoKit
import TookiKit

/// Saves copied images as PNG files in Application Support, named after their content.
@MainActor
enum ClipboardImageStore {
    static let directory = StoragePaths.dataDirectory.appending(path: "clipboard-images")
    private static let cache = NSCache<NSString, NSImage>()

    /// Saves the image on the pasteboard, or returns `nil` if there isn't one.
    static func save(from pasteboard: NSPasteboard) -> ClipboardImage? {
        let pngData = pasteboard.data(forType: .png)
        guard let data = pngData ?? pasteboard.data(forType: .tiff),
              let bitmap = NSBitmapImageRep(data: data),
              let png = pngData ?? bitmap.representation(using: .png, properties: [:])
        else { return nil }

        let hash = SHA256.hash(data: png).prefix(16).map { String(format: "%02x", $0) }.joined()
        let fileName = "\(hash).png"
        let url = directory.appending(path: fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard (try? png.write(to: url)) != nil else { return nil }
        }
        return ClipboardImage(fileName: fileName, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    static func url(for image: ClipboardImage) -> URL {
        directory.appending(path: image.fileName)
    }

    static func data(for image: ClipboardImage) -> Data? {
        try? Data(contentsOf: url(for: image))
    }

    /// Loads an image for display, keeping recently used ones in memory.
    static func nsImage(at url: URL) -> NSImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Deletes image files that are no longer in the history.
    static func removeUnused(keeping fileNames: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !fileNames.contains(file) {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
        }
    }
}
