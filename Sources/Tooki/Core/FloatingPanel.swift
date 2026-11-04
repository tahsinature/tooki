import AppKit
import SwiftUI

/// A borderless floating panel (like Spotlight) that takes keyboard input
/// without activating Tooki, so the app you were typing in stays frontmost.
final class FloatingPanel: NSPanel {
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

    override var canBecomeKey: Bool { true }

    /// Clicking anywhere else dismisses the panel.
    override func resignKey() {
        super.resignKey()
        close()
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
