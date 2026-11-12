import AppKit
import Quartz
import SwiftUI
import TookiKit

/// A borderless floating panel (like Spotlight) that takes keyboard input
/// without activating Tooki, so the app you were typing in stays frontmost.
final class FloatingPanel: NSPanel {
    /// Set by panels that offer Preview. Other panels keep their usual dismiss-on-blur behavior.
    var quickLook: QuickLookPreview?
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

    /// On ⌘Esc in any panel, closes it and runs `action` (the app opens root search).
    /// An app-wide monitor sees the key before any view can treat it as a plain Esc or a shortcut.
    @MainActor static func onCommandEscape(_ action: @escaping () -> Void) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == KeyCode.escape, event.modifierFlags.contains(.command),
                  let panel = NSApp.keyWindow as? FloatingPanel else { return event }
            panel.close()
            action()
            return nil
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if let onEscape { onEscape() } else { close() }
    }

    /// Clicking anywhere else dismisses the panel.
    override func resignKey() {
        super.resignKey()
        if quickLook?.isOpening == true { return }
        if QLPreviewPanel.sharedPreviewPanelExists(),
           let preview = QLPreviewPanel.shared(), preview.isVisible,
           let quickLook, preview.dataSource === quickLook { return }
        close()
    }

    override func close() {
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

    func present() {
        if let screen = NSScreen.main {
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
