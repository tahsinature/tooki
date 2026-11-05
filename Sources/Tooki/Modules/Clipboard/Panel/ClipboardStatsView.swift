import AppKit
import SwiftUI
import TookiKit

/// A row of small tiles: where the item came from, its size, and how often and when it was copied.
struct ClipboardStatsView: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 6) {
            if let app = SourceApp.named(item.sourceApp) {
                StatTile(caption: "source", value: app.name) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
                }
            }
            StatTile(caption: size.caption, value: size.value) { symbol(size.symbol) }
            StatTile(caption: "copied", value: "\(item.timesCopied)×") { symbol("repeat") }
                .help("First copied \(item.firstCopiedAt.formatted(date: .abbreviated, time: .shortened))")
            StatTile(caption: day, value: item.copiedAt.formatted(date: .omitted, time: .shortened)) { symbol("clock") }
                .help("Last copied \(item.copiedAt.formatted(date: .abbreviated, time: .shortened))")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(height: 16)
    }

    private var day: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(item.copiedAt) { return "today" }
        if calendar.isDateInYesterday(item.copiedAt) { return "yesterday" }
        return item.copiedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private var size: (symbol: String, value: String, caption: String) {
        if let image = item.image {
            return ("aspectratio", "\(image.width)×\(image.height)", "pixels")
        }
        if let files = item.files {
            let bytes = files.compactMap(Self.fileSize).reduce(0, +)
            let caption = files.count == 1 ? "size" : "\(files.count) files"
            return ("internaldrive", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file), caption)
        }
        let words = item.text.split { $0.isWhitespace || $0.isNewline }.count
        return words > 1
            ? ("text.word.spacing", "\(words)", "words")
            : ("character.cursor.ibeam", "\(item.text.count)", "characters")
    }

    private static func fileSize(_ path: String) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
    }
}

private struct StatTile<Icon: View>: View {
    let caption: String
    let value: String
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(spacing: 4) {
            icon
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Name and icon of the app an item was copied from. Lookups are cached.
@MainActor
struct SourceApp {
    let name: String
    let icon: NSImage?

    private static var cache: [String: SourceApp?] = [:]

    static func named(_ bundleID: String?) -> SourceApp? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { url in
            SourceApp(
                name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                icon: NSWorkspace.shared.icon(forFile: url.path)
            )
        }
        cache[bundleID] = app
        return app
    }
}
