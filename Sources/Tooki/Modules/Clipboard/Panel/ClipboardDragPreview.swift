import AppKit
import SwiftUI
import TookiKit

/// A compact card carried under the pointer while dragging a clipboard item.
struct ClipboardDragPreview: View {
    let item: ClipboardItem

    var body: some View {
        card
    }

    private var card: DragPreviewCard<ClipboardIcon> {
        DragPreviewCard(title: title, detail: detail) {
            ClipboardIcon(item: item, size: 40)
        }
    }

    private var title: String {
        if item.image != nil { return "Image" }
        if let path = item.files?.first { return URL(fileURLWithPath: path).lastPathComponent }
        return item.title
    }

    private var detail: String {
        if let files = item.files { return files.count == 1 ? "File" : "\(files.count.formatted()) files" }
        if let image = item.image { return "\(image.width) × \(image.height) pixels" }
        if item.contentType == .text { return "\(item.text.count.formatted()) characters" }
        return item.contentType.label
    }

    @MainActor
    static func image(for item: ClipboardItem, appearance: NSAppearance) -> NSImage {
        ClipboardDragPreview(item: item).card.image(appearance: appearance)
            ?? NSWorkspace.shared.icon(forFile: item.files?.first ?? "/")
    }
}
