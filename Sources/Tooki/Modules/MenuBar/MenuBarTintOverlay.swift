import AppKit
import TookiKit

/// Tints the menu bar on every screen with a panel just behind it, so the menu bar's own
/// blur softens the color and icons stay crisp. The tint part of Thaw 2's MenuBarOverlayPanel
/// (MenuBar/Appearance, https://github.com/thaw-app/Thaw, GPLv3).
@MainActor
final class MenuBarTintOverlay {
    private var tint = MenuBarTint()
    private var panels: [NSPanel] = []
    private var screenObserver: NSObjectProtocol?

    func apply(_ tint: MenuBarTint) {
        let needsPanels = tint.enabled && panels.isEmpty
        guard tint != self.tint || needsPanels else { return }
        self.tint = tint
        rebuild()
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            }
        }
    }

    private func rebuild() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
        guard tint.enabled, let color = RGBColor(hex: tint.color) else { return }
        let fill = NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: tint.opacity)
        panels = NSScreen.screens.map { panel(for: $0, color: fill) }
        panels.forEach { $0.orderFrontRegardless() }
    }

    private func panel(for screen: NSScreen, color: NSColor) -> NSPanel {
        let height = screen.menuBarHeight
        let frame = CGRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Behind the menu bar: in front of it, the panel would cover the icons too.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = color
        return panel
    }
}
