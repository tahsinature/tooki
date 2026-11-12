import AppKit

/// One native button owns both the icon and label, including the space around them.
@MainActor
final class SettingsToolbarButton: NSButton {
    private var hoverArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, image: NSImage?, target: AnyObject?, action: Selector) {
        let font = NSFont.systemFont(ofSize: 12)
        let width = max(44, (title as NSString).size(withAttributes: [.font: font]).width + 16)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 54))
        self.title = title
        self.image = image
        self.font = font
        self.target = target
        self.action = action
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .exterior
        setAccessibilityLabel(title)
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 54).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
    override var firstBaselineOffsetFromTop: CGFloat { 45 }
    override var lastBaselineOffsetFromBottom: CGFloat { 9 }

    override var state: NSControl.StateValue {
        didSet {
            needsDisplay = true
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        if state == .on || isHovered || isHighlighted {
            let opacity = isHighlighted ? 0.16 : (state == .on ? 0.11 : 0.07)
            NSColor.labelColor.withAlphaComponent(opacity).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9).fill()
        }
        let symbol = image?.withSymbolConfiguration(.init(paletteColors: [.labelColor])) ?? image
        if let symbol {
            let scale = 22 / max(1, max(symbol.size.width, symbol.size.height))
            let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            let rect = NSRect(x: (bounds.width - size.width) / 2, y: 7 + (22 - size.height) / 2,
                              width: size.width, height: size.height)
            symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        let text = NSAttributedString(string: title, attributes: [
            .font: font ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: state == .on ? NSColor.controlAccentColor : NSColor.secondaryLabelColor,
        ])
        text.draw(at: NSPoint(x: (bounds.width - text.size().width) / 2, y: 34))
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9).fill()
    }
}
