import SwiftUI
import TookiKit

/// The right column: a large preview above an Information section.
struct ClipboardDetailView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(spacing: 0) {
            ClipboardPreview(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            ClipboardInfoView(item: item)
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
                    .padding(16)
            }
        case .color:
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(HexColor(item.text).map(Color.init) ?? .clear)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
                    .frame(width: 140, height: 140)
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    .font(.title3.monospaced())
                    .textSelection(.enabled)
            }
        case .file:
            VStack(spacing: 10) {
                ClipboardIcon(item: item, size: 96)
                Text(item.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(6)
                if !item.missingFiles.isEmpty {
                    MissingFilesNotice(item: item)
                }
            }
            .padding(16)
        case .link, .text:
            ScrollView {
                Text(item.text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
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
