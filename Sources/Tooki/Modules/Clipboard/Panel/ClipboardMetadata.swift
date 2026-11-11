import Foundation
import TookiKit

/// The rows of the clipboard detail's "Information" list.
@MainActor
enum ClipboardMetadata {
    static func items(for item: ClipboardItem) -> [MetadataItem] {
        let source = SourceApp.named(item.sourceApp)
        let isText = item.contentType == .text || item.contentType == .link
        return [
            MetadataItem(label: "Source", value: source?.name, icon: source?.icon),
            MetadataItem(label: "Type", value: item.contentType.label),
            MetadataItem(label: "Dimensions", value: item.image.map { "\($0.width) × \($0.height)" }),
            MetadataItem(label: "Size", value: fileSize(of: item)),
            MetadataItem(label: "Characters", value: isText ? item.text.count.formatted() : nil),
            MetadataItem(label: "Words", value: isText ? wordCount(item.text).formatted() : nil),
            MetadataItem(label: "Times Copied", value: item.timesCopied > 1 ? item.timesCopied.formatted() : nil,
                         help: "First copied \(item.firstCopiedAt.formatted(date: .abbreviated, time: .shortened))"),
            MetadataItem(label: "Copied", value: relativeFormatter.localizedString(for: item.copiedAt, relativeTo: Date()),
                         help: item.copiedAt.formatted(date: .abbreviated, time: .shortened)),
        ]
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func fileSize(of item: ClipboardItem) -> String? {
        guard let files = item.files else { return nil }
        let bytes = files.compactMap { path in
            (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
        }.reduce(0, +)
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return files.count == 1 ? size : "\(size) in \(files.count) files"
    }
}
