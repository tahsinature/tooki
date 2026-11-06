import AppKit

/// Tooki's folded "T", with an overlaid development badge for dev builds.
enum MenuBarIcon {
    static let image = makeImage(color: .black, development: false)
    private static let lightDevelopmentImage = makeImage(color: .black, development: true)
    private static let darkDevelopmentImage = makeImage(color: .white, development: true)

    static func developmentImage(darkAppearance: Bool) -> NSImage {
        darkAppearance ? darkDevelopmentImage : lightDevelopmentImage
    }

    private static func makeImage(color: NSColor, development: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 2.5, width: 14, height: 4.5), xRadius: 1.2, yRadius: 1.2).fill()
            NSBezierPath(roundedRect: NSRect(x: 6.5, y: 6, width: 5, height: 10), xRadius: 1.2, yRadius: 1.2).fill()

            // The diagonal crease from the app icon.
            NSGraphicsContext.current?.compositingOperation = .clear
            let crease = NSBezierPath()
            crease.move(to: NSPoint(x: 6, y: 11.5))
            crease.line(to: NSPoint(x: 12, y: 7.5))
            crease.lineWidth = 1
            crease.stroke()

            NSGraphicsContext.current?.compositingOperation = .sourceOver
            if development {
                drawDevelopmentBadge()
            }
            return true
        }
        image.isTemplate = !development
        return image
    }

    private static func drawDevelopmentBadge() {
        let badge = NSRect(x: 3, y: 10.5, width: 15, height: 7.5)
        NSColor(calibratedRed: 1, green: 0.62, blue: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2).fill()

        let title = NSAttributedString(string: "DEV", attributes: [
            .font: NSFont.systemFont(ofSize: 5.5, weight: .black),
            .foregroundColor: NSColor(calibratedWhite: 0.07, alpha: 1),
        ])
        let size = title.size()
        title.draw(in: NSRect(
            x: badge.midX - size.width / 2,
            y: badge.midY - size.height / 2,
            width: size.width,
            height: size.height
        ))
    }
}
