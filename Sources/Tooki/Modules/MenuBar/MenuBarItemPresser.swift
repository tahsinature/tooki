import AppKit
import TookiKit

/// Clicks a menu bar item for you, revealing its section first when it's hidden.
/// Like Thaw, the click is a mouse event aimed at the icon's window; Accessibility's
/// press action is the fallback when that can't be delivered.
@MainActor
enum MenuBarItemPresser {
    static func press(_ item: MenuBarItem, organizer: MenuBarOrganizer) async {
        let section = organizer.section(of: item)
        let mustReveal = section != .shown && !organizer.reveals(section)
        if mustReveal {
            organizer.reveal(section)
            // Give macOS time to slide the icons back into view.
            try? await Task.sleep(for: .milliseconds(300))
        }

        let windowsBefore = windowNumbers(of: item.pid)
        guard await click(item) else {
            NSSound.beep()
            if mustReveal { organizer.collapse() }
            return
        }

        if mustReveal {
            await waitUntilMenuCloses(pid: item.pid, ignoring: windowsBefore)
            organizer.collapse()
        }
    }

    private static func click(_ item: MenuBarItem) async -> Bool {
        if let windowID = item.windowID,
           await MenuBarItemEvents.click(.init(windowID: windowID, pid: item.eventPID)) {
            return true
        }
        guard let element = item.element else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    /// The item's menu or popover is a new window of its app. Waits for one to
    /// appear and then for all of them to go away.
    private static func waitUntilMenuCloses(pid: pid_t, ignoring existing: Set<Int>) async {
        var menuWindows: Set<Int> = []
        for _ in 0..<10 where menuWindows.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
            menuWindows = windowNumbers(of: pid).subtracting(existing)
        }
        while !menuWindows.isEmpty {
            try? await Task.sleep(for: .milliseconds(400))
            menuWindows.formIntersection(windowNumbers(of: pid))
        }
    }

    /// Window numbers and owners are readable without the Screen Recording permission.
    private static func windowNumbers(of pid: pid_t) -> Set<Int> {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { info in
            info[kCGWindowOwnerPID as String] as? pid_t == pid ? info[kCGWindowNumber as String] as? Int : nil
        })
    }
}
