import AppKit
import Observation
import TookiKit

/// Thaw-style sections: icons left of Tooki's divider are hidden, and icons left of the optional
/// always-hidden divider stay hidden until everything is shown. A divider hides its section by
/// stretching and pushing those icons off screen. Hidden icons can instead be shown in the Thaw Bar.
/// Ported from Thaw 2 (MenuBar/MenuBarSection.swift, https://github.com/thaw-app/Thaw, GPLv3).
@MainActor
@Observable
final class MenuBarOrganizer {
    /// Which sections the dividers let into the menu bar.
    private(set) var revealState = MenuBarReveal.nothing
    /// Which sections the Thaw Bar shows, `.nothing` while it's closed.
    private(set) var thawBarState = MenuBarReveal.nothing

    var isCollapsed: Bool { revealState == .nothing && thawBarState == .nothing }

    @ObservationIgnored private var config = MenuBarConfig()
    @ObservationIgnored private var hiddenDivider: MenuBarDivider?
    @ObservationIgnored private var alwaysHiddenDivider: MenuBarDivider?
    @ObservationIgnored private var autoHideTask: Task<Void, Never>?
    @ObservationIgnored private var thawBarTask: Task<Void, Never>?
    @ObservationIgnored private lazy var thawBar = makeThawBar()
    @ObservationIgnored private lazy var triggers = MenuBarRevealTriggers(organizer: self)
    @ObservationIgnored private let tintOverlay = MenuBarTintOverlay()

    private static let hiddenDividerName = "TookiMenuBarSeparator"
    private static let alwaysHiddenDividerName = "TookiMenuBarAlwaysHiddenSeparator"

    var isInstalled: Bool { hiddenDivider != nil }
    var hasAlwaysHiddenSection: Bool { alwaysHiddenDivider != nil }

    /// Icons left of this screen position are hidden or always hidden.
    var hiddenBoundaryX: CGFloat? { hiddenDivider?.minX }

    /// Screen frames with a top-left origin, like the frames reported for other icons.
    var separatorFrame: CGRect? { hiddenDivider?.frame }
    var alwaysHiddenSeparatorFrame: CGRect? { alwaysHiddenDivider?.frame }

    /// The dividers by their layout ID, for arranging icons around them.
    var dividers: [String: MenuBarDivider] {
        var dividers: [String: MenuBarDivider] = [:]
        dividers[MenuBarLayoutPlanner.separatorID] = hiddenDivider
        dividers[MenuBarLayoutPlanner.alwaysHiddenSeparatorID] = alwaysHiddenDivider
        return dividers
    }

    /// The open Thaw Bar in AppKit screen coordinates.
    var thawBarFrame: CGRect? { thawBarState == .nothing ? nil : thawBar.frame }

    func apply(_ config: MenuBarConfig) {
        self.config = config
        if config.enabled {
            install()
        } else {
            uninstall()
        }
        var tint = config.tint
        tint.enabled = tint.enabled && config.enabled
        tintOverlay.apply(tint)
        triggers.apply(config)
    }

    func section(of item: MenuBarItem) -> MenuBarSection {
        MenuBarSection.of(
            midX: item.currentFrame.midX,
            hiddenDividerX: hiddenDivider?.minX,
            alwaysHiddenDividerX: alwaysHiddenDivider?.minX
        )
    }

    /// Whether the section's icons are in the menu bar right now. The Thaw Bar doesn't count.
    func reveals(_ section: MenuBarSection) -> Bool {
        revealState.reveals(section)
    }

    // MARK: Showing and hiding

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    /// Shows the hidden section, in the Thaw Bar when it's turned on.
    func expand(autoHide: Bool = true) {
        show(.hidden, autoHide: autoHide)
    }

    /// Shows the always-hidden section too.
    func showAll() {
        show(.all, autoHide: true)
    }

    /// Puts a section's icons into the menu bar, for clicking or moving them.
    func reveal(_ section: MenuBarSection) {
        guard isInstalled else { return }
        autoHideTask?.cancel()
        closeThawBar()
        setReveal(section == .alwaysHidden ? .all : .hidden)
    }

    func collapse() {
        guard isInstalled else { return }
        autoHideTask?.cancel()
        closeThawBar()
        setReveal(.nothing)
    }

    private func show(_ reveal: MenuBarReveal, autoHide: Bool) {
        guard isInstalled else { return }
        autoHideTask?.cancel()
        if config.useThawBar {
            setReveal(.nothing)
            openThawBar(reveal)
        } else {
            setReveal(reveal)
            if autoHide { scheduleAutoHide() }
        }
    }

    private func setReveal(_ reveal: MenuBarReveal) {
        revealState = reveal
        hiddenDivider?.setCollapsed(reveal.collapses(.hidden))
        alwaysHiddenDivider?.setCollapsed(reveal.collapses(.alwaysHidden))
    }

    private func scheduleAutoHide() {
        guard config.autoHideSeconds > 0 else { return }
        let delay = config.autoHideSeconds
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            collapse()
        }
    }

    // MARK: Thaw Bar

    private func makeThawBar() -> ThawBarPanel {
        let panel = ThawBarPanel()
        panel.onDismiss = { [weak self] in self?.thawBarState = .nothing }
        return panel
    }

    private func openThawBar(_ reveal: MenuBarReveal) {
        thawBarState = reveal
        thawBarTask?.cancel()
        thawBarTask = Task { [weak self] in
            let items = await MenuBarItemScanner.scan()
                .filter { item in
                    guard let section = self?.section(of: item) else { return false }
                    return section != .shown && reveal.reveals(section)
                }
                .sorted { $0.currentFrame.minX < $1.currentFrame.minX }
            guard let self, !Task.isCancelled, thawBarState == reveal else { return }
            let entries = items.enumerated().map { index, item in
                ThawBarEntry(id: index, item: item, captureImage: config.captureIconImages)
            }
            let placement = ThawBarPanel.Placement(location: config.thawBarLocation, dividerX: hiddenDivider?.frame?.maxX)
            thawBar.show(entries, style: config.thawBarStyle, placement: placement) { [weak self] item in
                guard let self else { return }
                closeThawBar()
                Task { await MenuBarItemPresser.press(item, organizer: self) }
            }
        }
    }

    private func closeThawBar() {
        thawBarTask?.cancel()
        guard thawBarState != .nothing else { return }
        thawBarState = .nothing
        thawBar.hide()
    }

    // MARK: Installing

    private func install() {
        let isNew = hiddenDivider == nil
        if isNew {
            hiddenDivider = MenuBarDivider(section: .hidden, autosaveName: Self.hiddenDividerName)
        }
        if config.alwaysHiddenSection, alwaysHiddenDivider == nil {
            alwaysHiddenDivider = MenuBarDivider(
                section: .alwaysHidden, autosaveName: Self.alwaysHiddenDividerName, leftOf: Self.hiddenDividerName
            )
        } else if !config.alwaysHiddenSection, let divider = alwaysHiddenDivider {
            divider.remove()
            alwaysHiddenDivider = nil
        }
        hiddenDivider?.setStyle(config.dividerStyle)
        alwaysHiddenDivider?.setStyle(config.dividerStyle)
        if !config.useThawBar { closeThawBar() }

        if isNew {
            config.startCollapsed ? collapse() : expand()
        } else {
            setReveal(revealState)
        }
    }

    private func uninstall() {
        autoHideTask?.cancel()
        closeThawBar()
        hiddenDivider?.remove()
        alwaysHiddenDivider?.remove()
        hiddenDivider = nil
        alwaysHiddenDivider = nil
        revealState = .nothing
    }
}
