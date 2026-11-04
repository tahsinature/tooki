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
