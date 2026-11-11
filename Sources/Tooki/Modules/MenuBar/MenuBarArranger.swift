import AppKit
import Observation
import TookiKit

/// Puts menu bar icons into the saved layout by ⌘-dragging them with targeted mouse events,
/// one at a time, and does it again whenever macOS shuffles them (app launches, wake, display changes).
@MainActor
@Observable
final class MenuBarArranger {
    private(set) var isArranging = false
    /// The outcome of the last run, shown in Settings.
    private(set) var status: String?

    @ObservationIgnored private let organizer: MenuBarOrganizer
    @ObservationIgnored private var config = MenuBarConfig()
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private static let maxMoves = 40
    private static let otherOrganizers = [
        "com.stonerl.Thaw": "Thaw",
        "com.jordanbaird.Ice": "Ice",
        "com.surteesstudios.Bartender": "Bartender",
        "com.dwarvesv.minimalbar": "Hidden Bar",
    ]

    init(organizer: MenuBarOrganizer) {
        self.organizer = organizer
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didLaunchApplicationNotification, delay: 3)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification, delay: 3)
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification, delay: 2)
    }

    func apply(_ config: MenuBarConfig) {
        let configurationChanged = config != self.config
        self.config = config
        if configurationChanged { scheduleRestore(after: 2) }
    }

    /// Another menu bar organizer that would fight over icon positions, if one is running.
    var conflictingApp: String? {
        NSWorkspace.shared.runningApplications.lazy.compactMap { Self.otherOrganizers[$0.bundleIdentifier ?? ""] }.first
    }

    func arrange(_ layout: MenuBarLayout) async {
        guard !isArranging, organizer.isInstalled else { return }
        isArranging = true
        defer { isArranging = false }
        let previousReveal = organizer.revealState
        // Every section must be in the menu bar to be measured and moved.
        organizer.reveal(.alwaysHidden)
        await pause(400)
        status = await moveIcons(into: layout)
        switch previousReveal {
        case .nothing: organizer.collapse()
        case .hidden: organizer.reveal(.hidden)
        case .all: organizer.reveal(.alwaysHidden)
        }
    }

    private func moveIcons(into layout: MenuBarLayout) async -> String? {
        var previousMove: MenuBarLayoutPlanner.Move?
        for _ in 0..<Self.maxMoves {
            guard !Task.isCancelled, organizer.isInstalled else { return "Arranging stopped." }
            let snapshot = await MenuBarSnapshot.capture(organizer: organizer)
            guard let move = MenuBarLayoutPlanner.nextMove(current: snapshot.order, layout: layout) else {
                return notchWarning(snapshot)
            }
            let title = snapshot.icon(move.item)?.title ?? move.item
            guard move != previousMove else { return "Couldn't move \(title). Try ⌘-dragging it by hand." }
            let (side, anchorID) = switch move.placement {
            case .before(let anchor): (MenuBarItemEvents.Side.left, anchor)
            case .after(let anchor): (MenuBarItemEvents.Side.right, anchor)
            }
            guard let item = snapshot.icon(move.item)?.target, let anchor = snapshot.icon(anchorID)?.target else {
                return "Couldn't find \(title) in the menu bar."
            }
            previousMove = move
            let anchorIsDivider = snapshot.dividers[anchorID] != nil
            let moved = await MenuBarItemEvents.move(item, to: side, of: anchor, anchorIsDivider: anchorIsDivider)
            // Moves wait for the user to let go of the mouse and keys, and give up if they don't.
            if !moved, NSEvent.pressedMouseButtons != 0 { return "Stopped because the mouse was in use." }
            await pause(150)
        }
        return "Stopped after \(Self.maxMoves) moves."
    }

    private func notchWarning(_ snapshot: MenuBarSnapshot) -> String? {
        let covered = snapshot.iconsUnderNotch.map(\.title)
        guard !covered.isEmpty else { return nil }
        return "Under the notch: \(covered.joined(separator: ", ")). Hide some icons to make room."
    }

    private func scheduleRestore(after seconds: Double) {
        restoreTask?.cancel()
        guard config.enabled, config.restoreLayout, let layout = config.layout else { return }
        restoreTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await arrange(layout)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, delay: Double) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRestore(after: delay) }
        })
    }

    private func pause(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
