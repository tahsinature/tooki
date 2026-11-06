import AppKit
import Quartz

/// Previews shelf items in the system Quick Look panel, the same one Finder opens with Space.
/// The panel asks the key window for its data, so `ShelfPanel` hands it over to this object.
@MainActor
final class ShelfQuickLook: NSObject {
    private var urls: [URL] = []
    /// ↑ and ↓ pressed while the preview is open. They move the shelf's selection,
    /// and the preview follows through `update(_:)`.
    var onArrowKey: (NSEvent) -> Bool = { _ in false }

    private var isShowing: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true
    }

    /// Opens Quick Look for these files, or closes it if it's already open.
    func toggle(_ urls: [URL]) {
        let panel = QLPreviewPanel.shared()
        if isShowing {
            panel?.orderOut(nil)
            return
        }
        guard !urls.isEmpty else { return NSSound.beep() }
        self.urls = urls
        // Tooki works in the background; Quick Look only takes keys (Space, arrows) when it's active.
        NSApp.activate()
        panel?.makeKeyAndOrderFront(nil)
        panel?.reloadData()
    }

    /// Shows these files instead, if the preview is open.
    func update(_ urls: [URL]) {
        guard isShowing, !urls.isEmpty, urls != self.urls, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
    }

    func takeControl(of panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = 0
    }

    func releaseControl(of panel: QLPreviewPanel) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

extension ShelfQuickLook: @preconcurrency QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}

extension ShelfQuickLook: @preconcurrency QLPreviewPanelDelegate {
    /// Up and Down go to the shelf; everything else (Left, Right, Space, Esc) stays with Quick Look.
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        let upAndDown: Set<UInt16> = [125, 126]
        guard event.type == .keyDown, upAndDown.contains(event.keyCode) else { return false }
        return onArrowKey(event)
    }
}
