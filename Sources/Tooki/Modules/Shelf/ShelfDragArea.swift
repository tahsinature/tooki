import AppKit
import SwiftUI

/// An invisible AppKit layer that drags shelf items out, and reports plain clicks.
/// SwiftUI's own drag API can't drag several files at once or tell when a drop finished.
struct ShelfDragArea: NSViewRepresentable {
    /// The items to drag, worked out when the drag starts.
    let items: () -> [ShelfItem]
    var onClick: (NSEvent) -> Void = { _ in }
    var tooltip: String?
    /// Where the tooltip shows, from the top left, worked out from the view's size. Everywhere if nil.
    var tooltipArea: ((CGSize) -> CGRect)?
    /// The right-click menu.
    var menu: () -> NSMenu? = { nil }
    /// Runs after the items were dropped somewhere. Not called when the drag is cancelled.
    let onDropped: ([ShelfItem]) -> Void

    func makeNSView(context: Context) -> ShelfDragSourceView {
        ShelfDragSourceView()
    }

    func updateNSView(_ view: ShelfDragSourceView, context: Context) {
        view.items = items
        view.onClick = onClick
        view.onDropped = onDropped
        view.contextMenu = menu
        // SwiftUI's `.help` can't show through this view, so it carries the tooltip itself.
        view.setToolTip(tooltip, in: tooltipArea)
    }
}

final class ShelfDragSourceView: NSView, NSDraggingSource, NSViewToolTipOwner {
    var items: () -> [ShelfItem] = { [] }
    var onClick: (NSEvent) -> Void = { _ in }
    var onDropped: ([ShelfItem]) -> Void = { _ in }
    var contextMenu: () -> NSMenu? = { nil }
    private var draggedItems: [ShelfItem] = []
    private var isDragging = false
    private var mouseDownPoint: CGPoint?
    /// A click often wobbles a little; only a real move starts a drag, as in Finder.
    private static let dragThreshold: CGFloat = 6

    private func hasMovedFarEnough(_ event: NSEvent) -> Bool {
        guard let start = mouseDownPoint else { return true }
        let point = event.locationInWindow
        return hypot(point.x - start.x, point.y - start.y) >= Self.dragThreshold
    }
    private var toolTipText: String?
    private var toolTipArea: ((CGSize) -> CGRect)?

    func setToolTip(_ text: String?, in area: ((CGSize) -> CGRect)?) {
        toolTipText = text
        toolTipArea = area
        updateToolTip()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateToolTip()
    }

    private func updateToolTip() {
        removeAllToolTips()
        guard toolTipText != nil else { return }
        guard let area = toolTipArea?(bounds.size) else { return toolTip = toolTipText }
        // The area is measured from the top, but this view counts from the bottom.
        let rect = CGRect(x: area.minX, y: bounds.height - area.maxY, width: area.width, height: area.height)
        addToolTip(rect, owner: self, userData: nil)
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        toolTipText ?? ""
    }

    // The panel moves when dragged by its background; this view must start a drag instead.
    override var mouseDownCanMoveWindow: Bool { false }

    // The shelf never takes focus, so the first click must already count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenu()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        mouseDownPoint = event.locationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging { onClick(event) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, hasMovedFarEnough(event) else { return }
        let items = items().filter(\.exists)
        guard !items.isEmpty else { return }
        isDragging = true
        draggedItems = items

        let start = convert(event.locationInWindow, from: nil)
        let picture = ShelfDragPreview.image(for: items, appearance: effectiveAppearance)
        let frame = CGRect(
            x: start.x - 24, y: start.y - picture.size.height + 16,
            width: picture.size.width, height: picture.size.height
        )
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: ShelfDragContent.writer(for: item))
            // Hide additional images while delivering every item to the destination.
            draggingItem.setDraggingFrame(frame, contents: index == 0 ? picture : nil)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
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
