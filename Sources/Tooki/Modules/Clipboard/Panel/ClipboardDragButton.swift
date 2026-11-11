import AppKit
import SwiftUI
import TookiKit

/// The action bar's Drag button: drag the item into another app, for places that can't paste.
struct ClipboardDragButton: View {
    let item: ClipboardItem
    /// Runs after the item was dropped somewhere. Not called when the drag is cancelled.
    let onDropped: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: "hand.draw")
            .font(.system(size: 14))
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(DragSource(item: item, isEnabled: isEnabled, onDropped: onDropped))
            .help(isEnabled ? "Drag this item into another app" : "The file no longer exists")
    }
}

/// The invisible AppKit view that starts the drag. SwiftUI's own drag API can't tell when a drop finished.
private struct DragSource: NSViewRepresentable {
    let item: ClipboardItem
    let isEnabled: Bool
    let onDropped: () -> Void

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.item = isEnabled ? item : nil
        view.onDropped = onDropped
        view.window?.invalidateCursorRects(for: view)
    }
}

private final class DragSourceView: NSView, NSDraggingSource {
    var item: ClipboardItem?
    var onDropped: (() -> Void)?

    // The panel moves when dragged by its background; this view must start a drag instead.
    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        if item != nil { addCursorRect(bounds, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        guard let item else { return }
        let writers = ClipboardDragContent.writers(for: item)
        guard !writers.isEmpty else { return }

        let start = convert(event.locationInWindow, from: nil)
        let picture = ClipboardDragContent.picture(for: item)
        let draggingItems = writers.enumerated().map { index, writer in
            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            // Stack multiple files slightly so they read as a pile.
            let offset = CGFloat(index) * 4
            let frame = CGRect(
                x: start.x - picture.size.width / 2 + offset,
                y: start.y - picture.size.height / 2 - offset,
                width: picture.size.width,
                height: picture.size.height
            )
            draggingItem.setDraggingFrame(frame, contents: picture)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation != [] else { return }
        // Let the drag session finish before the panel that owns this view closes.
        DispatchQueue.main.async { [onDropped] in onDropped?() }
    }
}

/// What a dragged clipboard item puts on the drag pasteboard, and how it looks under the pointer.
@MainActor
enum ClipboardDragContent {
    static func writers(for item: ClipboardItem) -> [NSPasteboardWriting] {
        if let image = item.image {
            // A named file, so upload fields show a readable name instead of a hash.
            return [ClipboardOpenWith.temporaryCopy(of: image) as NSURL]
        }
        if let files = item.files {
            return files.map { URL(fileURLWithPath: $0) as NSURL }
        }
        let text = item.text
        guard !text.isEmpty else { return [] }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(text, forType: .string)
        if item.contentType == .link {
            pasteboardItem.setString(text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .URL)
        }
        return [pasteboardItem]
    }

    static func picture(for item: ClipboardItem) -> NSImage {
        if let image = item.image,
           let nsImage = ClipboardImageStore.nsImage(at: ClipboardImageStore.url(for: image)) {
            return thumbnail(of: nsImage, maxSide: 96)
        }
        if let path = item.files?.first {
            return thumbnail(of: NSWorkspace.shared.icon(forFile: path), maxSide: 48)
        }
        let symbol = item.contentType == .link ? "link" : "doc.text"
        let configuration = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }

    private static func thumbnail(of image: NSImage, maxSide: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return NSImage(size: target, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
    }
}
