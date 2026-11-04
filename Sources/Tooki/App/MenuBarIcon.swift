import AppKit

/// Tooki's folded "T" for the menu bar. A template image, so macOS tints it for light and dark menu bars.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 2.5, width: 14, height: 4.5), xRadius: 1.2, yRadius: 1.2).fill()
            NSBezierPath(roundedRect: NSRect(x: 6.5, y: 6, width: 5, height: 10), xRadius: 1.2, yRadius: 1.2).fill()

            // The diagonal crease from the app icon.
            NSGraphicsContext.current?.compositingOperation = .clear
            let crease = NSBezierPath()
            crease.move(to: NSPoint(x: 6, y: 11.5))
            crease.line(to: NSPoint(x: 12, y: 7.5))
            crease.lineWidth = 1
            crease.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
