import AppKit
import Quartz
import SwiftUI
import TookiKit

/// A borderless floating panel (like Spotlight) that takes keyboard input
/// without activating Tooki, so the app you were typing in stays frontmost.
final class FloatingPanel: NSPanel {
    /// Set by panels that offer Preview. Other panels keep their usual dismiss-on-blur behavior.
    var quickLook: QuickLookPreview?
    /// Converters remain available while a temporary result is open in another app.
    var keepsOpenOnBlur = false
    var onClose: (() -> Void)?
    var onPresent: (() -> Void)?
    init<Content: View>(size: CGSize, @ViewBuilder content: () -> Content) {
        super.init(
            contentRect: CGRect(origin: .zero, size: size),
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

        let hosting = NSHostingView(rootView: content())
        hosting.frame = CGRect(origin: .zero, size: size)
        contentView = hosting
    }

    /// Runs when Esc reaches the panel, whichever view has focus. Closes the panel by default.
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        if let onEscape { onEscape() } else { close() }
    }

    /// Clicking anywhere else dismisses the panel.
    override func resignKey() {
        super.resignKey()
        if keepsOpenOnBlur { return }
        if quickLook?.isOpening == true { return }
        if QLPreviewPanel.sharedPreviewPanelExists(),
           let preview = QLPreviewPanel.shared(), preview.isVisible,
           let quickLook, preview.dataSource === quickLook { return }
        close()
    }

    override func close() {
        onClose?()
        quickLook?.close()
        super.close()
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated { quickLook != nil }
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { quickLook?.takeControl(of: panel) }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { quickLook?.releaseControl(of: panel) }
    }

    func present(restoring: Bool = false) {
        onPresent?()
        if !restoring, let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = CGPoint(
                x: visible.midX - frame.width / 2,
                y: visible.minY + visible.height * 0.72 - frame.height / 2
            )
            setFrameOrigin(origin)
        }
        makeKeyAndOrderFront(nil)
    }
}
