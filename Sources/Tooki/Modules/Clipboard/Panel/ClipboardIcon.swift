import SwiftUI
import TookiKit

/// A small picture of the item: colour swatch, image thumbnail, file icon or a symbol.
struct ClipboardIcon: View {
    let item: ClipboardItem
    let size: CGFloat

    var body: some View {
        Group {
            switch item.contentType {
            case .color:
                Circle()
                    .fill(HexColor(item.text).map(Color.init) ?? .clear)
                    .overlay(Circle().stroke(.separator))
                    .padding(size * 0.1)
            case .image:
                if let image = item.image, let thumbnail = ClipboardImageStore.nsImage(at: ClipboardImageStore.url(for: image)) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "photo")
                }
            case .file:
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.files?.first ?? "/"))
                    .resizable()
            case .link:
                Image(systemName: "link")
            case .text:
                Image(systemName: "doc.text")
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

extension Color {
    init(_ hex: HexColor) {
        self.init(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: hex.alpha)
    }
}
