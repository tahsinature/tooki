import AppKit
import SwiftUI

extension View {
    /// The frosted, rounded background of a floating panel: HUD blur with a translucent tint over it.
    func panelSurface() -> some View {
        background {
            ZStack {
                VisualEffectBackground(material: .hudWindow)
                PanelTheme.tint
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PanelTheme.cornerRadius, style: .continuous)
                .strokeBorder(PanelTheme.popupBorder, lineWidth: 1)
        )
    }
}

/// Blurs whatever is behind the window. SwiftUI's materials only blur inside the window.
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var cornerRadius: CGFloat = PanelTheme.cornerRadius

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        // Panels never activate Tooki, so without this the blur would look inactive.
        view.state = .active
        // SwiftUI's clip shape doesn't reach the blur, so it gets its own rounded mask.
        view.maskImage = Self.roundedMask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }

    /// A stretchable rounded rectangle: the corners keep their shape, the middle stretches.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
