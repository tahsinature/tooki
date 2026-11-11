import AppKit
import TookiKit

/// Shows hidden icons when the pointer hovers, clicks or scrolls on an empty part of the menu bar.
/// Ported from Thaw 2 (Events/HIDEventManager.swift, https://github.com/thaw-app/Thaw, GPLv3),
/// using event monitors instead of event taps since nothing is intercepted.
@MainActor
final class MenuBarRevealTriggers {
    private weak var organizer: MenuBarOrganizer?
    private var config = MenuBarConfig()
    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?
    private var rehideTask: Task<Void, Never>?
    private var isShownByHover = false
    private var appMenuCache: (pid: pid_t, maxX: CGFloat?, time: Date)?

    init(organizer: MenuBarOrganizer) {
        self.organizer = organizer
    }

    func apply(_ config: MenuBarConfig) {
        self.config = config
        let wanted = config.enabled && (config.showOnHover || config.showOnClick || config.showOnScroll)
        if wanted, monitors.isEmpty {
            startMonitoring()
        } else if !wanted, !monitors.isEmpty {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .scrollWheel]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) {
            monitors.append(global)
        }
        // Global monitors miss events sent to Tooki itself.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func stopMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        hoverTask?.cancel()
        rehideTask?.cancel()
        isShownByHover = false
    }

    private func handle(_ event: NSEvent) {
        guard let organizer, organizer.isInstalled else { return }
        switch event.type {
        case .mouseMoved where config.showOnHover:
            handleHover(organizer)
        case .leftMouseDown where config.showOnClick && isOverEmptyMenuBar():
            isShownByHover = false
            if event.modifierFlags.contains(.option) {
                organizer.revealState == .all ? organizer.collapse() : organizer.showAll()
            } else {
                organizer.toggle()
            }
        case .scrollWheel where config.showOnScroll && isOverEmptyMenuBar():
            switch MenuBarTriggerZone.scrollReveals(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY) {
            case true?: if organizer.isCollapsed { organizer.expand() }
            case false?: organizer.collapse()
            case nil: break
            }
        default:
            break
        }
    }

    // MARK: Hover

    private func handleHover(_ organizer: MenuBarOrganizer) {
        if organizer.isCollapsed {
            isShownByHover = false
            rehideTask?.cancel()
            guard hoverTask == nil, isOverEmptyMenuBar() else { return }
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(config.showOnHoverDelay))
                hoverTask = nil
                guard !Task.isCancelled, organizer.isCollapsed, isOverEmptyMenuBar() else { return }
                organizer.expand(autoHide: false)
                isShownByHover = true
            }
        } else if isShownByHover, rehideTask == nil, !isNearShownIcons(organizer) {
            // Like Thaw's rehide strategy: hide again once the pointer leaves, unless a menu is open.
            rehideTask = Task {
                try? await Task.sleep(for: .seconds(max(config.showOnHoverDelay, 0.3)))
                rehideTask = nil
                guard !Task.isCancelled, isShownByHover, !isNearShownIcons(organizer), !isMenuOpen() else { return }
                isShownByHover = false
                organizer.collapse()
            }
        }
    }

    private func isNearShownIcons(_ organizer: MenuBarOrganizer) -> Bool {
        let mouse = NSEvent.mouseLocation
        if let bar = organizer.thawBarFrame, bar.insetBy(dx: -8, dy: -8).contains(mouse) { return true }
        guard let location = CGEvent(source: nil)?.location else { return false }
        return NSScreen.screens.contains { $0.menuBarFrame.contains(location) }
    }

    private func isMenuOpen() -> Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { $0[kCGWindowLayer as String] as? Int == menuLevel }
    }

    // MARK: Where the pointer is

    private func isOverEmptyMenuBar() -> Bool {
        guard let location = CGEvent(source: nil)?.location,
              let screen = NSScreen.screens.first(where: { $0.menuBarFrame.contains(location) })
        else { return false }
        return MenuBarTriggerZone.isEmptySpace(
            location,
            menuBar: screen.menuBarFrame,
            appMenuMaxX: appMenuMaxX(),
            notch: screen.notchFrame,
            itemFrames: WindowServer.menuBarItemWindows().map(\.frame)
        )
    }

    /// The right edge of the active app's menus. Cached briefly, since reading it is slow.
    private func appMenuMaxX() -> CGFloat? {
        guard let app = NSWorkspace.shared.menuBarOwningApplication else { return nil }
        if let cache = appMenuCache, cache.pid == app.processIdentifier, cache.time.timeIntervalSinceNow > -2 {
            return cache.maxX
        }
        let maxX = Self.appMenuMaxX(pid: app.processIdentifier)
        appMenuCache = (app.processIdentifier, maxX, Date())
        return maxX
    }

    private static func appMenuMaxX(pid: pid_t) -> CGFloat? {
        let app = AXUIElementCreateApplication(pid)
        var menuBar: CFTypeRef?
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBar, CFGetTypeID(menuBar) == AXUIElementGetTypeID(),
              AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
              let lastMenu = (children as? [AXUIElement])?.last
        else { return nil }
        var position: CFTypeRef?
        var size: CFTypeRef?
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXUIElementCopyAttributeValue(lastMenu, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(lastMenu, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent)
        else { return nil }
        return origin.x + extent.width
    }
}
