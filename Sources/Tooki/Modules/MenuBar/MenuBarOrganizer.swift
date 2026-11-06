import AppKit
import Observation
import TookiKit

/// Bartender-style hiding: icons placed left of Tooki's separator are pushed
/// off-screen by stretching the separator. Users choose icons by ⌘-dragging them.
@MainActor
@Observable
final class MenuBarOrganizer {
    private(set) var isCollapsed = false

    @ObservationIgnored private var config = MenuBarConfig()
    @ObservationIgnored private var separatorItem: NSStatusItem?
    @ObservationIgnored private var autoHideTask: Task<Void, Never>?

    private static let separatorLength: CGFloat = 14
    private static let collapsedLength: CGFloat = 10_000

    var isInstalled: Bool { separatorItem != nil }

    /// Icons left of this screen position are in the hidden section.
    var hiddenBoundaryX: CGFloat? { separatorItem?.button?.window?.frame.minX }

    /// Screen frames with a top-left origin, like the frames Accessibility reports for other icons.
    var separatorFrame: CGRect? { separatorItem.flatMap(Self.screenFrame) }

    private static func screenFrame(of item: NSStatusItem) -> CGRect? {
        guard let frame = item.button?.window?.frame, let primary = NSScreen.screens.first else { return nil }
        return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }

    func apply(_ config: MenuBarConfig) {
        let wasInstalled = isInstalled
        self.config = config
        if config.enabled, !wasInstalled {
            install()
        } else if !config.enabled, wasInstalled {
            uninstall()
        }
    }

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    func expand(autoHide: Bool = true) {
        guard isInstalled else { return }
        autoHideTask?.cancel()
        separatorItem?.length = Self.separatorLength
        isCollapsed = false
        updateSeparatorIcon()
        if autoHide { scheduleAutoHide() }
    }

    func collapse() {
        guard isInstalled else { return }
        autoHideTask?.cancel()
        separatorItem?.length = Self.collapsedLength
        isCollapsed = true
        updateSeparatorIcon()
    }

    private func install() {
        let separator = NSStatusBar.system.statusItem(withLength: Self.separatorLength)
        separator.autosaveName = "TookiMenuBarSeparator"
        separator.button?.appearsDisabled = true
        separator.button?.toolTip = "Icons left of this line are hidden"

        separatorItem = separator
        // No placement delay or second status item is needed to hide icons.
        if config.startCollapsed {
            collapse()
        } else {
            expand()
        }
    }

    private func uninstall() {
        autoHideTask?.cancel()
        if let separatorItem {
            separatorItem.length = Self.separatorLength
            NSStatusBar.system.removeStatusItem(separatorItem)
        }
        separatorItem = nil
        isCollapsed = false
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        guard config.autoHideSeconds > 0 else { return }
        let delay = config.autoHideSeconds
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            collapse()
        }
    }

    private func updateSeparatorIcon() {
        separatorItem?.button?.image = isCollapsed ? nil : symbol("poweron")
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        return image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
    }
}
