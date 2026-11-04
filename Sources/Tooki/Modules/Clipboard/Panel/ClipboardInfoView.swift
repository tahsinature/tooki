import AppKit
import SwiftUI
import TookiKit

/// Information rows under the preview, like Raycast's.
struct ClipboardInfoView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Information")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            if let app = SourceApp.named(item.sourceApp) {
                InfoRow(label: "Application") {
                    HStack(spacing: 6) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
                        Text(app.name)
                    }
                }
            }
            InfoRow(label: "Content type") { Text(item.contentType.label) }
            ForEach(details, id: \.label) { detail in
                InfoRow(label: detail.label) { Text(detail.value).lineLimit(1).truncationMode(.middle) }
            }
            InfoRow(label: "Times copied") { Text("\(item.timesCopied)") }
            InfoRow(label: "Last copied") { Text(item.copiedAt.formatted(date: .abbreviated, time: .shortened)) }
            InfoRow(label: "First copied") { Text(item.firstCopiedAt.formatted(date: .abbreviated, time: .shortened)) }
        }
        .font(.callout)
        .padding(14)
    }

    private var details: [(label: String, value: String)] {
        if let image = item.image {
            return [("Dimensions", "\(image.width)×\(image.height)")]
        }
        if let files = item.files {
            let size = files.compactMap(Self.fileSize).reduce(0, +)
            return [
                (files.count == 1 ? "Path" : "Files", files.count == 1 ? files[0] : "\(files.count)"),
                ("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file)),
            ]
        }
        let words = item.text.split { $0.isWhitespace || $0.isNewline }.count
        return [("Characters", "\(item.text.count)"), ("Words", "\(words)")]
    }

    private static func fileSize(_ path: String) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
    }
}

private struct InfoRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 16)
                value
            }
            .padding(.vertical, 5)
            Divider()
        }
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
