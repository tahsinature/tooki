import AppKit

/// One native button owns both the icon and label, including the space around them.
@MainActor
final class SettingsToolbarButton: NSButton {
    private let tile: NSImage?
    private var hoverArea: NSTrackingArea?
    private var isHovered = false

    // The toolbar caps item height at 56. The tile and label are centered with equal gaps in the pill.
    private static let height: CGFloat = 56
    private static let tileTop: CGFloat = 7
    private static let labelTop: CGFloat = 34
    /// The pill's inset from the button edges, so it never touches the title bar.
    private static let pillInset = NSSize(width: 2, height: 2)

    /// Animated from 0 to 1 as the pointer enters, so hover fades in and out.
    @objc dynamic var hoverAmount: CGFloat = 0 { didSet { needsDisplay = true } }
    /// Animated from 0 to 1 as the page is selected.
    @objc dynamic var selectionAmount: CGFloat = 0 { didSet { needsDisplay = true } }

    var showsBadge = false { didSet { needsDisplay = true } }

    init(title: String, tile: NSImage?, target: AnyObject?, action: Selector) {
        self.tile = tile
        let font = NSFont.systemFont(ofSize: 12)
        let width = max(48, (title as NSString).size(withAttributes: [.font: font]).width + 20)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        self.title = title
        self.font = font
        self.target = target
        self.action = action
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .exterior
        setAccessibilityLabel(title)
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    /// The titlebar's vibrancy would wash out the colored tiles.
    override var allowsVibrancy: Bool { false }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
    override var firstBaselineOffsetFromTop: CGFloat { 46 }
    override var lastBaselineOffsetFromBottom: CGFloat { 10 }

    override static func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
        key == "hoverAmount" || key == "selectionAmount" ? CABasicAnimation() : super.defaultAnimation(forKey: key)
    }

    override var state: NSControl.StateValue {
        didSet { animate("selectionAmount", to: state == .on ? 1 : 0) }
    }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }

    private func setHovered(_ hovered: Bool) {
        isHovered = hovered
        animate("hoverAmount", to: hovered ? 1 : 0)
    }

    /// Uses key-value coding, which the animator proxy needs to interpolate the property.
    private func animate(_ key: String, to value: CGFloat) {
        guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            setValue(value, forKey: key)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setValue(value, forKey: key)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBackground()

        // The tile lifts slightly on hover.
        let side = SettingsToolbarTile.size * (1 + 0.06 * hoverAmount)
        let tileRect = NSRect(x: (bounds.width - side) / 2, y: Self.tileTop + (SettingsToolbarTile.size - side) / 2, width: side, height: side)
        SettingsToolbarTile.draw(tile, in: tileRect, isPressed: isHighlighted)
        if showsBadge { SettingsToolbarTile.drawBadge(at: tileRect) }

        drawLabel()
    }

    private func drawBackground() {
        let opacity = isHighlighted ? 0.16 : max(0.11 * selectionAmount, 0.07 * hoverAmount)
        guard opacity > 0 else { return }
        let pill = NSBezierPath(roundedRect: pillRect, xRadius: 10, yRadius: 10)
        NSColor.labelColor.withAlphaComponent(opacity).setFill()
        pill.fill()
        NSColor.labelColor.withAlphaComponent(opacity * 0.6).setStroke()
        pill.lineWidth = 0.5
        pill.stroke()
    }

    private func drawLabel() {
        let resting = NSColor.secondaryLabelColor.blended(withFraction: hoverAmount, of: .labelColor) ?? .secondaryLabelColor
        let color = resting.blended(withFraction: selectionAmount, of: .controlAccentColor) ?? resting
        let text = NSAttributedString(string: title, attributes: [
            .font: font ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: color,
        ])
        text.draw(at: NSPoint(x: (bounds.width - text.size().width) / 2, y: Self.labelTop))
    }

    private var pillRect: NSRect {
        bounds.insetBy(dx: Self.pillInset.width, dy: Self.pillInset.height)
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: pillRect, xRadius: 10, yRadius: 10).fill()
    }
}
