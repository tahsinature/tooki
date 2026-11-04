import AppKit

/// One icon in the menu bar, read through Accessibility.
/// `@unchecked Sendable` because AXUIElement is safe to use from any thread.
struct MenuBarItem: @unchecked Sendable {
    let element: AXUIElement
    let pid: pid_t
    let appName: String
    let bundleID: String?
    /// The accessibility title or description, e.g. "Wi‑Fi, connected, 3 bars". Often empty.
    let label: String
    /// Screen position, with the origin at the top left of the main screen.
    let frame: CGRect

    /// "Wi‑Fi" for "Wi‑Fi, connected, 3 bars", or the app name when the item has no label.
    var title: String {
        let firstPart = label.split(separator: ",").first.map(String.init) ?? ""
        let trimmed = firstPart.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? appName : trimmed
    }

    var isOnScreen: Bool {
        NSScreen.screens.contains { $0.frame.minX <= frame.midX && frame.midX < $0.frame.maxX }
    }
}

/// Finds the menu bar items of every running app, Apple's own included.
enum MenuBarItemScanner {
    private struct AppInfo: Sendable {
        let pid: pid_t
        let name: String
        let bundleID: String?
    }

    static func scan() async -> [MenuBarItem] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID }
            .map { AppInfo(pid: $0.processIdentifier, name: $0.localizedName ?? "Unknown", bundleID: $0.bundleIdentifier) }
        return await Task.detached { scan(apps) }.value
    }

    /// Asks all apps at once, because each answer takes a few milliseconds.
    private nonisolated static func scan(_ apps: [AppInfo]) -> [MenuBarItem] {
        var itemsPerApp = [[MenuBarItem]](repeating: [], count: apps.count)
        itemsPerApp.withUnsafeMutableBufferPointer { buffer in
            // Safe: each app writes only to its own slot.
            nonisolated(unsafe) let slots = buffer
            DispatchQueue.concurrentPerform(iterations: apps.count) { index in
                slots[index] = items(of: apps[index])
            }
        }
        return itemsPerApp.flatMap { $0 }
    }

    private nonisolated static func items(of app: AppInfo) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.pid)
        // An app that hangs must not stall the whole scan.
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        guard let extrasBar: AXUIElement = attribute(appElement, "AXExtrasMenuBar"),
              let children: [AXUIElement] = attribute(extrasBar, kAXChildrenAttribute)
        else { return [] }

        return children.compactMap { element in
            let frame = frame(of: element)
            // Control Center lists items it is not currently drawing with an empty frame.
            guard frame.width > 0, frame.origin != .zero else { return nil }
            let title: String = attribute(element, kAXTitleAttribute) ?? ""
            let description: String = attribute(element, kAXDescriptionAttribute) ?? ""
            return MenuBarItem(
                element: element,
                pid: app.pid,
                appName: app.name,
                bundleID: app.bundleID,
                label: title.isEmpty ? description : title,
                frame: frame
            )
        }
    }

    private nonisolated static func frame(of element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero
        var size = CGSize.zero
        if let value: AXValue = attribute(element, kAXPositionAttribute) {
            AXValueGetValue(value, .cgPoint, &origin)
        }
        if let value: AXValue = attribute(element, kAXSizeAttribute) {
            AXValueGetValue(value, .cgSize, &size)
        }
        return CGRect(origin: origin, size: size)
    }

    private nonisolated static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
