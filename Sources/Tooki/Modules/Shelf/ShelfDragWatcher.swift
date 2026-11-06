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
    private var localMonitor: Any?
    /// Drags that start in Tooki (moving a shelf, dragging an item out) never open a shelf.
    private var dragStartedInTooki = false
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
        // Global monitors don't see Tooki's own clicks, so watch those here.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.dragStartedInTooki = true
            return event
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        localMonitor.map(NSEvent.removeMonitor)
        self.monitor = nil
        localMonitor = nil
        didFire = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragPasteboardCount = NSPasteboard(name: .drag).changeCount
            dragStartedInTooki = false
            didFire = false
        case .leftMouseUp:
            if didFire { onDragEnded() }
            didFire = false
        default:
            guard !didFire, !dragStartedInTooki,
                  event.modifierFlags.contains(.shift),
                  NSEvent.pressedMouseButtons & 1 != 0,
                  NSPasteboard(name: .drag).changeCount != dragPasteboardCount
            else { return }
            didFire = true
            onShiftDrag()
        }
    }
}
