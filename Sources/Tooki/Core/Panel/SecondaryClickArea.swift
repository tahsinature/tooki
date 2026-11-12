import AppKit
import SwiftUI

/// Receives secondary clicks while leaving primary clicks and drags to the row underneath.
struct SecondaryClickArea: NSViewRepresentable {
    let onClick: () -> Void

    func makeNSView(context: Context) -> SecondaryClickView { SecondaryClickView() }

    func updateNSView(_ view: SecondaryClickView, context: Context) {
        view.onClick = onClick
    }
}

final class SecondaryClickView: NSView {
    var onClick: () -> Void = {}

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        let isControlClick = event.type == .leftMouseDown && event.modifierFlags.contains(.control)
        guard event.type == .rightMouseDown || isControlClick else { return nil }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) { onClick() }
    override func mouseDown(with event: NSEvent) { onClick() }
}
