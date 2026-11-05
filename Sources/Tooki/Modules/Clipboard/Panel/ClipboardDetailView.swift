import SwiftUI
import TookiKit

/// The right column: a preview, stat tiles and the item's actions.
struct ClipboardDetailView: View {
    let item: ClipboardItem
    let targetAppName: String?
    let onAction: (ClipboardAction.Kind) -> Void
    let onShowActions: () -> Void
    let onDropped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClipboardPreview(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            ClipboardStatsView(item: item)
            ClipboardActionBar(
                item: item,
                targetAppName: targetAppName,
                onAction: onAction,
                onShowActions: onShowActions,
                onDropped: onDropped
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }
}

private struct ClipboardPreview: View {
    let item: ClipboardItem

    var body: some View {
        switch item.contentType {
        case .image:
            if let image = item.image, let nsImage = ClipboardImageStore.nsImage(at: ClipboardImageStore.url(for: image)) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .color:
            ColorPreview(text: item.text)
        case .file:
            FilePreview(item: item)
        case .link, .text:
            ScrollView {
                Text(item.text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06)))
        }
    }
}

private struct ColorPreview: View {
    let text: String

    var body: some View {
        let color = HexColor(text)
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.map(Color.init) ?? .clear)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    .font(.system(size: 24, weight: .semibold))
                if let color {
                    Text("\(color.rgbDescription) · \(color.hslDescription)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct FilePreview: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClipboardIcon(item: item, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                Text((item.files ?? []).joined(separator: "\n"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
            if !item.missingFiles.isEmpty {
                MissingFilesNotice(item: item)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// Explains why a file item can't be pasted, dragged or opened any more.
private struct MissingFilesNotice: View {
    let item: ClipboardItem

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var message: String {
        let missing = item.missingFiles.count
        let total = item.files?.count ?? missing
        if total == 1 { return "This file no longer exists" }
        return missing == total ? "These files no longer exist" : "\(missing) of \(total) files no longer exist"
    }
}
