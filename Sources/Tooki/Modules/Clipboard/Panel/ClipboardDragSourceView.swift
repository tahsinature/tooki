import AppKit
import TookiKit

/// Starts a drag and reports successful drops, including drops in other apps.
final class ClipboardDragSourceView: NSView, NSDraggingSource {
    var item: ClipboardItem?
    var onDropped: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func resetCursorRects() {
        if item != nil { addCursorRect(bounds, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        guard let item else { return }
        let writers = ClipboardDragContent.writers(for: item)
        guard !writers.isEmpty else { return }

        onHover?(false)
        let start = convert(event.locationInWindow, from: nil)
        let picture = ClipboardDragPreview.image(for: item, appearance: effectiveAppearance)
        let frame = CGRect(
            x: start.x - 24,
            y: start.y - picture.size.height + 16,
            width: picture.size.width,
            height: picture.size.height
        )
        let draggingItems = writers.enumerated().map { index, writer in
            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            // One card represents the group; every file still reaches the drop target.
            draggingItem.setDraggingFrame(frame, contents: index == 0 ? picture : nil)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation != [] else { return }
        // Finish the drag session before closing its owning panel.
        DispatchQueue.main.async { [onDropped] in onDropped?() }
    }
}
