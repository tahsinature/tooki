import AppKit

/// Notices when you hold Shift while dragging something in any app, so the shelf can appear.
///
/// A drag is only a drag of content when it starts a drag session, which changes the system
/// drag pasteboard. That keeps Shift-click-drag text selection and window moves from counting.
@MainActor
final class ShelfDragWatcher {
    var onShiftDrag: () -> Void = {}
    var onDragEnded: () -> Void = {}

    private var monitor: Any?
    private var dragPasteboardCount = 0
    private var didFire = false

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]
        ) { [weak self] event in
            // Global monitors run on the main thread.
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        didFire = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragPasteboardCount = NSPasteboard(name: .drag).changeCount
            didFire = false
        case .leftMouseUp:
            if didFire { onDragEnded() }
            didFire = false
        default:
            guard !didFire,
                  event.modifierFlags.contains(.shift),
                  NSEvent.pressedMouseButtons & 1 != 0,
                  NSPasteboard(name: .drag).changeCount != dragPasteboardCount
            else { return }
            didFire = true
            onShiftDrag()
        }
    }
}
