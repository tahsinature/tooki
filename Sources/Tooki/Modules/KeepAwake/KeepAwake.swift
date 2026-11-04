import AppKit
import IOKit.ps
import IOKit.pwr_mgt
import Observation
import TookiKit

/// Keeps the Mac (and optionally the display) awake using a power assertion,
/// the same mechanism as Amphetamine or KeepingYouAwake.
@MainActor
@Observable
final class KeepAwake {
    /// When manual Keep Awake ends. `.distantFuture` means until turned off; `nil` means off.
    private(set) var manualUntil: Date?
    /// Name of the running app that currently keeps the Mac awake, if any.
    private(set) var triggeringApp: String?
    private(set) var isActive = false

    @ObservationIgnored private var config = KeepAwakeConfig()
    @ObservationIgnored private var assertionID: IOPMAssertionID = 0
    @ObservationIgnored private var heldAssertionType: String?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func apply(_ config: KeepAwakeConfig) {
        self.config = config
        refresh()
    }

    /// - Parameter minutes: `nil` or `0` keeps the Mac awake until turned off.
    func start(minutes: Int?) {
        if let minutes, minutes > 0 {
            manualUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            manualUntil = .distantFuture
        }
        refresh()
    }

    func stop() {
        manualUntil = nil
        refresh()
    }

    func toggle() {
        manualUntil == nil ? start(minutes: config.defaultDurationMinutes) : stop()
    }

    func shutdown() {
        manualUntil = nil
        setAssertion(nil)
    }

    var statusText: String {
        if let manualUntil {
            if manualUntil == .distantFuture { return "On until turned off" }
            return "On until \(manualUntil.formatted(date: .omitted, time: .shortened))"
        }
        if let triggeringApp { return "On while \(triggeringApp) is running" }
        return "Off"
    }

    private func refresh() {
        if let manualUntil, manualUntil <= Date() { self.manualUntil = nil }
        triggeringApp = runningTriggerApp()

        let wanted = manualUntil != nil || triggeringApp != nil
        let allowedByPower = !config.onlyOnPower || isOnACPower()
        setAssertion(wanted && allowedByPower ? assertionType(for: config.mode) : nil)
    }

    private func runningTriggerApp() -> String? {
        guard !config.activateForApps.isEmpty else { return nil }
        let app = NSWorkspace.shared.runningApplications.first {
            guard let bundleID = $0.bundleIdentifier else { return false }
            return config.activateForApps.contains(bundleID)
        }
        return app?.localizedName ?? app?.bundleIdentifier
    }

    private func assertionType(for mode: KeepAwakeMode) -> String {
        switch mode {
        case .display: "PreventUserIdleDisplaySleep"
        case .system: "PreventUserIdleSystemSleep"
        }
    }

    private func setAssertion(_ type: String?) {
        guard type != heldAssertionType else { return }
        if heldAssertionType != nil {
            IOPMAssertionRelease(assertionID)
            heldAssertionType = nil
        }
        if let type {
            var newID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Tooki Keep Awake" as CFString,
                &newID
            )
            if result == kIOReturnSuccess {
                assertionID = newID
                heldAssertionType = type
            }
        }
        isActive = heldAssertionType != nil
    }

    private func isOnACPower() -> Bool {
        guard let source = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() else { return true }
        return (source as String) == "AC Power"
    }
}
