import AppKit

/// Clicks a menu bar item for you, revealing hidden icons first when needed.
@MainActor
enum MenuBarItemPresser {
    static func press(_ item: MenuBarItem, organizer: MenuBarOrganizer) async {
        let mustReveal = !item.isOnScreen && organizer.isCollapsed
        if mustReveal {
            organizer.expand()
            // Give macOS time to slide the icons back into view.
            try? await Task.sleep(for: .milliseconds(300))
        }

        let windowsBefore = windowNumbers(of: item.pid)
        guard AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success else {
            NSSound.beep()
            if mustReveal { organizer.collapse() }
            return
        }

        if mustReveal {
            await waitUntilMenuCloses(pid: item.pid, ignoring: windowsBefore)
            organizer.collapse()
        }
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
