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

    private struct PressIdentity: Hashable {
        let keyCode: Int64
        let timestamp: CGEventTimestamp
    }

    private struct PendingPress {
        let identity: PressIdentity
        let combo: KeyCombo
        let frontApp: NSRunningApplication?
        var deliveredTo: pid_t?
    }

    private static let historyLimit = 6
    /// How long to wait for a press to show up at the app before calling it taken.
    private static let deliveryTimeout = Duration.milliseconds(250)

    @ObservationIgnored private let deliveryTap: any ShortcutDeliveryWatching
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var sessionID: UUID?
    @ObservationIgnored private var timeouts: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var idsByEvent: [PressIdentity: UUID] = [:]
    @ObservationIgnored private var catalog = ShortcutCatalog(entries: [])
    @ObservationIgnored private var pending: [UUID: PendingPress] = [:]
    @ObservationIgnored private var swallowedKeyCodes: Set<Int64> = []

    init(deliveryTap: any ShortcutDeliveryWatching = DeliveryTap(),
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await ContinuousClock().sleep(for: $0) }) {
        self.deliveryTap = deliveryTap
        self.sleep = sleep
    }

    isolated deinit { stop() }

    /// Returns `false` when the keyboard can't be watched (no Accessibility permission).
    func start(catalog: ShortcutCatalog) -> Bool {
        self.catalog = catalog
        guard !isListening else { return true }
        let session = UUID()
        sessionID = session
        let started = deliveryTap.start { [weak self] keyCode, timestamp, pid in
            guard let self, sessionID == session,
                  let id = idsByEvent[PressIdentity(keyCode: keyCode, timestamp: timestamp)] else { return }
            pending[id]?.deliveredTo = pid
        }
        isListening = started
        if !started { sessionID = nil }
        return started
    }

    func stop() {
        deliveryTap.stop()
        sessionID = nil
        timeouts.values.forEach { $0.cancel() }
        timeouts = [:]
        idsByEvent = [:]
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
        let id = UUID()
        let identity = PressIdentity(keyCode: keyCode, timestamp: event.timestamp)
        guard idsByEvent[identity] == nil else { return false }
        pending[id] = PendingPress(identity: identity, combo: combo, frontApp: frontApp)
        idsByEvent[identity] = id
        let session = sessionID
        timeouts[id] = Task { [weak self, sleep] in
            do { try await sleep(Self.deliveryTimeout) } catch { return }
            guard !Task.isCancelled else { return }
            self?.finish(id, session: session)
        }
        return false
    }

    private func finish(_ id: UUID, session: UUID?) {
        guard sessionID == session, let press = pending.removeValue(forKey: id) else { return }
        idsByEvent.removeValue(forKey: press.identity)
        timeouts.removeValue(forKey: id)
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
