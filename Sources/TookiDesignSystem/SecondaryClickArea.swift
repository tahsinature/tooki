import AppKit
import SwiftUI

/// Receives secondary clicks while leaving primary clicks and drags to the row underneath.
public struct SecondaryClickArea: NSViewRepresentable {
    let onClick: () -> Void

    public init(onClick: @escaping () -> Void) { self.onClick = onClick }

    public func makeNSView(context: Context) -> SecondaryClickView { SecondaryClickView() }

    public func updateNSView(_ view: SecondaryClickView, context: Context) {
        view.onClick = onClick
    }
}

public final class SecondaryClickView: NSView {
    var onClick: () -> Void = {}

    public override var mouseDownCanMoveWindow: Bool { false }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        let isControlClick = event.type == .leftMouseDown && event.modifierFlags.contains(.control)
        guard event.type == .rightMouseDown || isControlClick else { return nil }
        return super.hitTest(point)
    }

    public override func rightMouseDown(with event: NSEvent) { onClick() }
    public override func mouseDown(with event: NSEvent) { onClick() }
}
