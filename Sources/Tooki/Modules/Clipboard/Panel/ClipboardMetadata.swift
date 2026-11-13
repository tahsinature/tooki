import Foundation
import TookiKit

/// Formats the clipboard preview's information.
@MainActor
enum ClipboardMetadata {
    static func detail(for item: ClipboardItem) -> String? {
        switch item.contentType {
        case .image:
            item.image.map { "\($0.width) × \($0.height) px" }
        case .text, .link:
            "\(item.text.count.formatted()) characters · \(wordCount(item.text).formatted()) words"
        case .file:
            item.files.map { $0.count == 1 ? "1 file" : "\($0.count.formatted()) files" }
        case .color:
            HexColor(item.text)?.rgbDescription
        }
    }

    static func copiedDescription(for item: ClipboardItem) -> String {
        if abs(item.copiedAt.timeIntervalSinceNow) < 1 { return "Just now" }
        return relativeFormatter.localizedString(for: item.copiedAt, relativeTo: Date())
    }

    static func copyHistory(for item: ClipboardItem) -> String {
        let copied = "Copied \(item.copiedAt.formatted(date: .abbreviated, time: .shortened))"
        guard item.timesCopied > 1 else { return copied }
        return "\(copied)\n\(item.timesCopied.formatted()) times copied\nFirst copied \(item.firstCopiedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Reads file attributes rather than decoding or loading the image's bytes.
    static func fileSize(of item: ClipboardItem) -> String? {
        let urls: [URL]
        if let image = item.image {
            urls = [ClipboardImageStore.url(for: image)]
        } else if let files = item.files, !files.isEmpty {
            urls = files.map { URL(filePath: $0) }
        } else {
            return nil
        }
        var bytes: Int64 = 0
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true, let size = values.fileSize else { return nil }
            bytes += Int64(size)
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
