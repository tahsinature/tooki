import Foundation
import TookiKit

/// The local files backing image and file entries, used by Preview and Copy Path.
@MainActor
enum ClipboardFileURLs {
    static func urls(for item: ClipboardItem) -> [URL] {
        guard item.canBeUsed else { return [] }
        if let image = item.image {
            let url = ClipboardImageStore.url(for: image)
            return FileManager.default.fileExists(atPath: url.path) ? [url] : []
        }
        return (item.files ?? []).map { URL(fileURLWithPath: $0) }
    }
}
