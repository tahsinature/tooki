import SwiftUI
import TookiKit

/// The right column: a preview of the item, then its details.
struct ClipboardDetailView: View {
    let item: ClipboardItem
    /// Runs when the item was dragged into another app.
    let onDropped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClipboardPreview(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .topTrailing) {
                    // A finished drop works like a paste, so the panel closes.
                    ClipboardDragButton(item: item, onDropped: onDropped)
                        .frame(width: 28, height: 28)
                        .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 8))
                        .disabled(!item.canBeUsed)
                        .padding(10)
                }
            MetadataList(title: "Information", items: ClipboardMetadata.items(for: item))
        }
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
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PanelTheme.border))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .color:
            ColorPreview(text: item.text)
        case .file:
            FilePreview(item: item)
        case .link, .text:
            ScrollView {
                Text(item.text)
                    .font(PanelTheme.monoFont)
                    .lineSpacing(5)
                    .foregroundStyle(PanelTheme.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
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
        .padding(16)
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
        .padding(16)
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
