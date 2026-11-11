import AppKit

/// One icon in the menu bar.
/// `@unchecked Sendable` because AXUIElement is safe to use from any thread.
struct MenuBarItem: @unchecked Sendable {
    /// The Accessibility element, used for its title and as a fallback for clicking.
    let element: AXUIElement?
    /// The app the icon belongs to.
    let pid: pid_t
    let appName: String
    let bundleID: String?
    /// The accessibility identifier, e.g. "com.apple.menuextra.wifi". Mostly set by Apple's items.
    let identifier: String?
    /// The accessibility title or description, e.g. "Wi‑Fi, connected, 3 bars". Often empty.
    let label: String
    /// Screen position, with the origin at the top left of the main screen.
    let frame: CGRect
    /// The icon's own window, which synthetic mouse events are aimed at.
    var windowID: CGWindowID?
    /// The process that receives the icon's mouse events: Control Center on macOS 26, the app before.
    var eventPID: pid_t

    /// "Wi‑Fi" for "Wi‑Fi, connected, 3 bars", or the app name when the item has no label.
    var title: String {
        let firstPart = label.split(separator: ",").first.map(String.init) ?? ""
        let trimmed = firstPart.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? appName : trimmed
    }

    var isOnScreen: Bool {
        NSScreen.screens.contains { $0.frame.minX <= frame.midX && frame.midX < $0.frame.maxX }
    }

    /// The frame right now, which changes while sections are revealed or icons move.
    var currentFrame: CGRect {
        windowID.flatMap(WindowServer.frame(of:)) ?? frame
    }
}
