import AppKit
import SwiftUI
import TookiKit

/// Thaw's "Thaw Bar": a strip below the menu bar showing a hidden section's icons, so they
/// can be used without making room in the menu bar. Ported from Thaw 2 (MenuBar/IceBar/IceBar.swift,
/// https://github.com/thaw-app/Thaw, GPLv3).
@MainActor
final class ThawBarPanel: NSPanel {
    private var outsideClickMonitor: Any?
    /// Runs when the bar closes because the user clicked elsewhere.
    var onDismiss: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    struct Placement {
        let location: ThawBarLocation
        /// The divider's right edge, for `.underDivider`.
        let dividerX: CGFloat?
    }

    func show(_ entries: [ThawBarEntry], style: ThawBarStyle, placement: Placement, onPress: @escaping (MenuBarItem) -> Void) {
        let hosting = FirstMouseHostingView(rootView: ThawBarView(entries: entries, style: style, onPress: onPress))
        let size = hosting.fittingSize
        contentView = hosting
        setFrame(frame(for: size, placement: placement), display: true)
        orderFrontRegardless()
        startMonitoringOutsideClicks()
    }

    func hide() {
        orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    /// Centered under the pointer, the divider or at the right, just below the menu bar of the screen in use.
    private func frame(for size: CGSize, placement: Placement) -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let x = ThawBarPlacement.x(
            for: placement.location, width: size.width,
            screenMinX: screen.frame.minX, screenMaxX: screen.frame.maxX,
            mouseX: mouse.x, dividerX: placement.dividerX
        )
        let y = screen.frame.maxY - screen.menuBarHeight - size.height - 4
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func startMonitoringOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        // Global monitors only see clicks in other apps, which are all outside the bar.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hide()
                self.onDismiss?()
            }
        }
    }
}

/// The panel never becomes key, so the first click must reach the buttons directly.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
