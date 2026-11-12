import AppKit
import SwiftUI

/// A settings page's toolbar icon: the app's colored IconTile, drawn by the AppKit toolbar button.
@MainActor
enum SettingsToolbarTile {
    static let size: CGFloat = 24

    static func image(for page: SettingsPage) -> NSImage? {
        let renderer = ImageRenderer(content: IconTile(symbol: page.icon, color: page.tileColor, size: size))
        renderer.scale = 2
        return renderer.nsImage
    }

    static func draw(_ tile: NSImage?, in rect: NSRect, isPressed: Bool) {
        tile?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if isPressed {
            NSColor.black.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.24, yRadius: rect.height * 0.24).fill()
        }
    }

    static func drawBadge(at tile: NSRect) {
        let dot = NSRect(x: tile.maxX - 6, y: tile.minY - 3, width: 9, height: 9)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }
}
