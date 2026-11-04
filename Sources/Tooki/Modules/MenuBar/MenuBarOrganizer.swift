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
    @ObservationIgnored private var toggleItem: NSStatusItem?
    @ObservationIgnored private var separatorItem: NSStatusItem?
    @ObservationIgnored private var toggleTarget: ActionTarget?
    @ObservationIgnored private var autoHideTask: Task<Void, Never>?

    private static let separatorLength: CGFloat = 14
    private static let collapsedLength: CGFloat = 10_000

    var isInstalled: Bool { toggleItem != nil }

    /// Icons left of this screen position are in the hidden section.
    var hiddenBoundaryX: CGFloat? { separatorItem?.button?.window?.frame.minX }

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

    func expand() {
        separatorItem?.length = Self.separatorLength
        isCollapsed = false
        updateToggleIcon()
        scheduleAutoHide()
    }

    func collapse() {
        // Only collapse when the separator sits left of the toggle, or the toggle would vanish too.
        guard let separatorX = separatorItem?.button?.window?.frame.minX,
              let toggleX = toggleItem?.button?.window?.frame.minX,
              separatorX < toggleX
        else { return }
        autoHideTask?.cancel()
        separatorItem?.length = Self.collapsedLength
        isCollapsed = true
        updateToggleIcon()
    }

    private func install() {
        // Items created later appear further left, so the separator starts left of the toggle.
        let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggle.autosaveName = "TookiMenuBarToggle"
        let target = ActionTarget { [weak self] in self?.toggle() }
        toggle.button?.target = target
        toggle.button?.action = #selector(ActionTarget.fire)
        toggle.button?.toolTip = "Show or hide menu bar icons (⌘-drag icons left of │ to hide them)"

        let separator = NSStatusBar.system.statusItem(withLength: Self.separatorLength)
        separator.autosaveName = "TookiMenuBarSeparator"
        separator.button?.image = symbol("poweron")
        separator.button?.appearsDisabled = true
        separator.button?.toolTip = "Icons left of this line are hidden"

        toggleItem = toggle
        separatorItem = separator
        toggleTarget = target
        updateToggleIcon()

        if config.startCollapsed {
            Task {
                // Wait until macOS has placed the new items.
                try? await Task.sleep(for: .milliseconds(500))
                collapse()
            }
        }
    }

    private func uninstall() {
        autoHideTask?.cancel()
        [toggleItem, separatorItem].compactMap { $0 }.forEach(NSStatusBar.system.removeStatusItem)
        toggleItem = nil
        separatorItem = nil
        toggleTarget = nil
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

    private func updateToggleIcon() {
        toggleItem?.button?.image = symbol(isCollapsed ? "chevron.left" : "chevron.right")
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        return image?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
    }
}

/// Bridges AppKit target/action to a Swift closure.
final class ActionTarget: NSObject {
    private let handler: @MainActor () -> Void

    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @MainActor @objc func fire() {
        handler()
    }
}
