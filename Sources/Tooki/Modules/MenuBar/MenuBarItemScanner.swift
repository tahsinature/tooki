import AppKit
import TookiKit

/// Finds the menu bar items of every running app, Apple's own included.
/// Like Thaw, the Window Server lists the icon windows and Accessibility names them:
/// each window is paired with the Accessibility element at the same spot.
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
        return await Task.detached { attachWindows(to: scan(apps), apps: apps, ownPID: ownPID) }.value
    }

    /// Gives each item its window, and adds the windows of apps that list no items to Accessibility.
    /// Without Window Server access the Accessibility items are returned unchanged.
    private nonisolated static func attachWindows(to items: [MenuBarItem], apps: [AppInfo], ownPID: pid_t) -> [MenuBarItem] {
        var windows = WindowServer.menuBarItemWindows()
        var result = items.map { item in
            var item = item
            if let index = MenuBarFrameMatcher.index(matching: item.frame, in: windows.map(\.frame)) {
                item.windowID = windows[index].id
                item.eventPID = windows[index].ownerPID
                windows.remove(at: index)
            }
            return item
        }
        let appsByPID = Dictionary(apps.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        let appsWithItems = Set(items.map(\.pid))
        // On macOS 26 Control Center owns every window, so unmatched ones can't be named and are skipped.
        for window in windows where window.ownerPID != ownPID && !appsWithItems.contains(window.ownerPID) {
            guard let app = appsByPID[window.ownerPID], app.bundleID != "com.apple.controlcenter" else { continue }
            result.append(MenuBarItem(
                element: nil, pid: app.pid, appName: app.name, bundleID: app.bundleID, identifier: nil, label: "",
                frame: window.frame, windowID: window.id, eventPID: window.ownerPID
            ))
        }
        return result
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
                identifier: attribute(element, kAXIdentifierAttribute),
                label: title.isEmpty ? description : title,
                frame: frame,
                windowID: nil,
                eventPID: app.pid
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
