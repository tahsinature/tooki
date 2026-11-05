import AppKit
import SwiftUI

/// An invisible AppKit layer that drags shelf items out, and reports plain clicks.
/// SwiftUI's own drag API can't drag several files at once or tell when a drop finished.
struct ShelfDragArea: NSViewRepresentable {
    /// The items to drag, worked out when the drag starts.
    let items: () -> [ShelfItem]
    var onClick: (NSEvent) -> Void = { _ in }
    var tooltip: String?
    /// Runs after the items were dropped somewhere. Not called when the drag is cancelled.
    let onDropped: ([ShelfItem]) -> Void

    func makeNSView(context: Context) -> ShelfDragSourceView {
        ShelfDragSourceView()
    }

    func updateNSView(_ view: ShelfDragSourceView, context: Context) {
        view.items = items
        view.onClick = onClick
        view.onDropped = onDropped
        // SwiftUI's `.help` can't show through this view, so it carries the tooltip itself.
        view.toolTip = tooltip
    }
}

final class ShelfDragSourceView: NSView, NSDraggingSource {
    var items: () -> [ShelfItem] = { [] }
    var onClick: (NSEvent) -> Void = { _ in }
    var onDropped: ([ShelfItem]) -> Void = { _ in }
    private var draggedItems: [ShelfItem] = []
    private var isDragging = false

    // The panel moves when dragged by its background; this view must start a drag instead.
    override var mouseDownCanMoveWindow: Bool { false }

    // The shelf never takes focus, so the first click must already count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging { onClick(event) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging else { return }
        let items = items().filter(\.exists)
        guard !items.isEmpty else { return }
        isDragging = true
        draggedItems = items

        let start = convert(event.locationInWindow, from: nil)
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: ShelfDragContent.writer(for: item))
            // Stack the first few slightly so they read as a pile.
            let offset = CGFloat(min(index, 3)) * 4
            let frame = CGRect(x: start.x - 24 + offset, y: start.y - 24 - offset, width: 48, height: 48)
            draggingItem.setDraggingFrame(frame, contents: item.icon)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self).draggingFormation = .pile
    }

    // Copy, move or link, as the destination decides; Finder applies its usual rules, as it would for a Finder drag.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let dropped = draggedItems
        draggedItems = []
        guard operation != [] else { return }
        // Let the drag session finish before the panel may hide.
        DispatchQueue.main.async { [onDropped] in onDropped(dropped) }
    }
}

/// What a dragged shelf item puts on the drag pasteboard.
@MainActor
private enum ShelfDragContent {
    static func writer(for item: ShelfItem) -> NSPasteboardWriting {
        guard let text = item.text else { return item.url as NSURL }
        // Text fields take the text or link; Finder and upload fields take the saved file.
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)
        pasteboardItem.setString(text, forType: .string)
        if item.isLink { pasteboardItem.setString(text, forType: .URL) }
        return pasteboardItem
    }
}

extension ShelfItem {
    /// The file's Finder icon.
    @MainActor var icon: NSImage {
        // A copy still being made has no file yet, so it borrows the original's icon.
        NSWorkspace.shared.icon(forFile: exists ? path : (originalPath ?? path))
    }
}
