import AppKit

/// Moves a menu bar icon the way a person does: by holding ⌘ and dragging it.
/// macOS has no API for this, so the drag is replayed as mouse events.
enum MenuBarItemMover {
    /// Drags the icon at `frame` to `x` and puts the cursor back where it was.
    static func drag(_ frame: CGRect, toX x: CGFloat) async {
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let end = CGPoint(x: x, y: frame.midY)
        let savedCursor = CGEvent(source: nil)?.location ?? start
        let source = CGEventSource(stateID: .hidSystemState)

        CGWarpMouseCursorPosition(start)
        await pause(50)
        post(.leftMouseDown, at: start, source: source)
        await pause(150)
        // Small steps, so the menu bar sees a real drag and makes room for the icon.
        let steps = 15
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            post(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y), source: source)
            await pause(16)
        }
        await pause(150)
        post(.leftMouseUp, at: end, source: source)
        await pause(100)
        CGWarpMouseCursorPosition(savedCursor)
    }

    private static func post(_ type: CGEventType, at point: CGPoint, source: CGEventSource?) {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
    }

    private static func pause(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
