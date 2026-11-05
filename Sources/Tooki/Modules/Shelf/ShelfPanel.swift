import AppKit
import SwiftUI

/// The floating shelf window. Unlike `FloatingPanel` it stays open when you click elsewhere,
/// and it never takes focus away from the app you're working in.
final class ShelfPanel: NSPanel {
    /// Handles a key press while the shelf is focused. Returns `false` to let it through.
    var onKey: (NSEvent) -> Bool = { _ in false }
    var onEscape: () -> Void = {}

    init(shelf: Shelf, content: some View) {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 168, height: 168),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // Tooki is usually in the background while you use the shelf.
        allowsToolTipsWhenApplicationIsInactive = true
        let hostingView = FirstClickHostingView(rootView: content)
        // The view reports its size and `ShelfPanelController` resizes the panel to match.
        hostingView.sizingOptions = []
        contentView = ShelfDropView(shelf: shelf, content: hostingView)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    override func keyDown(with event: NSEvent) {
        if !onKey(event) { super.keyDown(with: event) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onKey(event) || super.performKeyEquivalent(with: event)
    }
}

/// The shelf never takes focus, so its buttons must react to the first click.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The panel's content view: accepts anything dropped on the shelf and hosts the SwiftUI content.
private final class ShelfDropView: NSView {
    private let shelf: Shelf

    init(shelf: Shelf, content: NSView) {
        self.shelf = shelf
        super.init(frame: .zero)
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes([.fileURL, .URL, .string, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Items dragged out of the shelf don't land back on it.
        guard !(sender.draggingSource is ShelfDragSourceView) else { return [] }
        shelf.dropTarget = target(for: sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !(sender.draggingSource is ShelfDragSourceView) else { return [] }
        shelf.dropTarget = target(for: sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        shelf.dropTarget = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let mode: ShelfAddMode = shelf.dropTarget == .files(.copy) ? .copy : .original
        shelf.dropTarget = nil
        return shelf.add(from: sender.draggingPasteboard, mode: mode)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        shelf.dropTarget = nil
    }

    /// Files over the left half link to the originals; over the right half they're copied.
    private func target(for sender: NSDraggingInfo) -> ShelfDropTarget {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else {
            return .content
        }
        let x = convert(sender.draggingLocation, from: nil).x
        return .files(x < bounds.midX ? .original : .copy)
    }
}
