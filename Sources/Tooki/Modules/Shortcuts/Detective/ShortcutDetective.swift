import AppKit
import TookiKit

/// The outcome of one shortcut press.
struct DetectiveCheck: Identifiable {
    enum Verdict {
        /// The press reached an app. `menuItem` is the menu item it triggers there, if any.
        case reachedApp(String, menuItem: String?)
        /// Something took the press before any app, and Tooki knows what.
        case taken(by: [KnownShortcut])
        /// Something took the press, but it isn't in any list Tooki can read.
        case takenByUnknown(frontApp: String, interceptors: [String])
        /// The press was blocked (test mode "Don't run"). These are the owners Tooki could look up.
        case lookedUp([KnownShortcut], frontApp: String, menuItem: String?)
    }

    let id = UUID()
    let combo: KeyCombo
    let date = Date()
    let verdict: Verdict
}

/// Finds out who takes a shortcut. Sits in the keyboard pipeline right after the Hyper key,
/// notes each press, then checks whether `DeliveryTap` saw it arrive at an app.
@MainActor
@Observable
final class ShortcutDetective: KeyEventHandler {
    enum TestMode: CaseIterable {
        /// Let the press through and watch who takes it. Finds any owner, but the shortcut runs.
        case runShortcut
        /// Block the press so nothing runs, and only look up owners Tooki knows about.
        case dontRun
    }

    private(set) var isListening = false
    var testMode = TestMode.runShortcut
    /// Newest first.
    private(set) var checks: [DetectiveCheck] = []

    private struct PendingPress {
        let combo: KeyCombo
        let frontApp: NSRunningApplication?
        var deliveredTo: pid_t?
    }

    private static let historyLimit = 6
    /// How long to wait for a press to show up at the app before calling it taken.
    private static let deliveryTimeout: TimeInterval = 0.25

    @ObservationIgnored private let deliveryTap = DeliveryTap()
    @ObservationIgnored private var catalog = ShortcutCatalog(entries: [])
    @ObservationIgnored private var pending: [Int64: PendingPress] = [:]
    @ObservationIgnored private var swallowedKeyCodes: Set<Int64> = []

    /// Returns `false` when the keyboard can't be watched (no Accessibility permission).
    func start(catalog: ShortcutCatalog) -> Bool {
        self.catalog = catalog
        let started = deliveryTap.start { [weak self] keyCode, pid in
            self?.pending[keyCode]?.deliveredTo = pid
        }
        isListening = started
        return started
    }

    func stop() {
        deliveryTap.stop()
        pending = [:]
        isListening = false
    }

    func clearHistory() {
        checks = []
    }

    func handle(_ event: CGEvent, type: CGEventType) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp { return swallowedKeyCodes.remove(keyCode) != nil }
        guard isListening, type == .keyDown,
              let combo = KeyCombo(keyCode: UInt16(keyCode), modifiers: KeyCombo.Modifiers(event.flags))
        else { return false }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return swallowedKeyCodes.contains(keyCode) }

        let frontApp = NSWorkspace.shared.frontmostApplication
        if testMode == .dontRun {
            swallowedKeyCodes.insert(keyCode)
            record(combo, lookUp(combo, frontApp: frontApp))
            return true
        }
        pending[keyCode] = PendingPress(combo: combo, frontApp: frontApp)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deliveryTimeout) { [weak self] in
            self?.finish(keyCode)
        }
        return false
    }

    private func finish(_ keyCode: Int64) {
        guard let press = pending.removeValue(forKey: keyCode) else { return }
        record(press.combo, verdict(for: press))
    }

    private func verdict(for press: PendingPress) -> DetectiveCheck.Verdict {
        if let pid = press.deliveredTo {
            let app = NSRunningApplication(processIdentifier: pid)
            return .reachedApp(app?.localizedName ?? "an app", menuItem: menuItem(for: press.combo, in: app))
        }
        let owners = catalog.matches(press.combo)
        if !owners.isEmpty { return .taken(by: owners) }
        return .takenByUnknown(frontApp: press.frontApp?.localizedName ?? "the app", interceptors: KeyInterceptors.running())
    }

    private func lookUp(_ combo: KeyCombo, frontApp: NSRunningApplication?) -> DetectiveCheck.Verdict {
        .lookedUp(catalog.matches(combo), frontApp: frontApp?.localizedName ?? "the app", menuItem: menuItem(for: combo, in: frontApp))
    }

    /// Tooki's own menus are skipped: asking ourselves over Accessibility from the main thread would stall.
    private func menuItem(for combo: KeyCombo, in app: NSRunningApplication?) -> String? {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return MenuShortcutFinder.menuItem(for: combo, in: app.processIdentifier)
    }

    private func record(_ combo: KeyCombo, _ verdict: DetectiveCheck.Verdict) {
        checks.insert(DetectiveCheck(combo: combo, verdict: verdict), at: 0)
        if checks.count > Self.historyLimit { checks.removeLast() }
    }
}
