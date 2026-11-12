import AppKit
import TookiKit

/// The pasteboard content delivered when a clipboard item is dragged into another app.
@MainActor
enum ClipboardDragContent {
    static func writers(for item: ClipboardItem) -> [NSPasteboardWriting] {
        if let image = item.image {
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
}
