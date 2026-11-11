import AppKit
import TookiKit

/// One of Tooki's dividers, a status item that hides the icons to its left by stretching to
/// 10,000 points and pushing them off screen. The same trick as Thaw's control items
/// (Thaw 2 ControlItem.swift and MenuBarSection.swift, https://github.com/thaw-app/Thaw, GPLv3).
@MainActor
final class MenuBarDivider {
    let section: MenuBarSection
    private let statusItem: NSStatusItem
    private(set) var isCollapsed = false
    private var style = MenuBarDividerStyle.line

    private static let collapsedLength: CGFloat = 10_000

    /// `leftOf` is a divider that must stay to the right of this one the first time it appears.
    init(section: MenuBarSection, autosaveName: String, leftOf neighbour: String? = nil) {
        self.section = section
        if let neighbour { Self.seedPosition(of: autosaveName, leftOf: neighbour) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = autosaveName
        statusItem.button?.appearsDisabled = true
        statusItem.button?.toolTip = section == .alwaysHidden
            ? "Icons left of this line stay hidden until you show all icons"
            : "Icons left of this line are hidden"
        update()
    }

    /// The left edge on screen. Icons left of it belong to this divider's section.
    var minX: CGFloat? { statusItem.button?.window?.frame.minX }

    /// Screen frame with a top-left origin, like the frames Accessibility and the Window Server report.
    var frame: CGRect? {
        guard let frame = statusItem.button?.window?.frame, let primary = NSScreen.screens.first else { return nil }
        return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }

    /// The divider's window as the Window Server knows it, for aiming moves at. Found by position
    /// because on macOS 26 Control Center owns the window and its number differs from ours.
    var eventTarget: MenuBarItemEvents.Target? {
        guard let frame else { return nil }
        let windows = WindowServer.menuBarItemWindows()
        guard let index = MenuBarFrameMatcher.index(matching: frame, in: windows.map(\.frame)) else { return nil }
        return MenuBarItemEvents.Target(windowID: windows[index].id, pid: windows[index].ownerPID)
    }

    func setCollapsed(_ collapsed: Bool) {
        isCollapsed = collapsed
        update()
    }

    func setStyle(_ style: MenuBarDividerStyle) {
        self.style = style
        update()
    }

    func remove() {
        statusItem.length = NSStatusItem.variableLength
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func update() {
        statusItem.length = isCollapsed ? Self.collapsedLength : expandedLength
        statusItem.button?.image = isCollapsed ? nil : symbol
    }

    private var expandedLength: CGFloat { style == .invisible ? 6 : 14 }

    private var symbol: NSImage? {
        let name: String? = switch style {
        case .line: "poweron"
        case .chevron: section == .alwaysHidden ? "chevron.left.2" : "chevron.left"
        case .invisible: nil
        }
        guard let name else { return nil }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        return image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
    }

    /// macOS places a new status item by its saved distance from the right edge. Seeding it
    /// just past the neighbour's puts the new divider immediately to its left, as Thaw does.
    private static func seedPosition(of name: String, leftOf neighbour: String) {
        let defaults = UserDefaults.standard
        let key = { (name: String) in "NSStatusItem Preferred Position \(name)" }
        guard defaults.object(forKey: key(name)) == nil,
              let neighbourPosition = defaults.object(forKey: key(neighbour)) as? Double
        else { return }
        defaults.set(neighbourPosition + 1, forKey: key(name))
    }
}
