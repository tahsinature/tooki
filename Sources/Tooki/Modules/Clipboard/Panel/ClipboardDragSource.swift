import AppKit
import SwiftUI
import TookiKit

/// The AppKit drag source also reports hover because it receives the pointer events.
struct ClipboardDragSource: NSViewRepresentable {
    let item: ClipboardItem
    let isEnabled: Bool
    @Binding var isHovered: Bool
    let onDropped: () -> Void

    func makeNSView(context: Context) -> ClipboardDragSourceView {
        ClipboardDragSourceView()
    }

    func updateNSView(_ view: ClipboardDragSourceView, context: Context) {
        view.item = isEnabled ? item : nil
        view.onDropped = onDropped
        view.onHover = { isHovered = $0 }
        view.toolTip = isEnabled ? "Drag this item into another app" : "The file no longer exists"
        view.window?.invalidateCursorRects(for: view)
    }
}
