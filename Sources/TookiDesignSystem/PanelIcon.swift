import AppKit
import SwiftUI

/// An SF Symbol or an image (an app icon, a thumbnail) shown in a panel row.
public enum PanelIcon {
    case symbol(String)
    case image(NSImage)
}

/// Draws a `PanelIcon` at a fixed size. Symbols sit smaller than the box, like Asyar's row glyphs.
public struct PanelIconView: View {
    let icon: PanelIcon
    var size: CGFloat = PanelTheme.rowIconSize

    public init(icon: PanelIcon, size: CGFloat = PanelTheme.rowIconSize) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        Group {
            switch icon {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.64))
            case .image(let image):
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }
}
