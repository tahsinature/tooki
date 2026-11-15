import AppKit
import ComposableArchitecture
import IOKit.ps
import KeepAwakeFeature
import Observation
import TookiKit

/// Adapts reducer state to workspace/power notifications and a serial native assertion owner.
@MainActor
@Observable
final class KeepAwake {
    let store: StoreOf<KeepAwakeFeature>
    @ObservationIgnored private let assertions: PowerAssertionController
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var powerSource: CFRunLoopSource?

    init() {
        let assertions = PowerAssertionController()
        self.assertions = assertions
        store = Store(initialState: KeepAwakeFeature.State()) { KeepAwakeFeature() } withDependencies: {
            $0.keepAwakeClient = KeepAwakeClient(setAssertion: { mode in
                await MainActor.run { assertions.set(mode) }
            })
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshEnvironment() }
            })
        }
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<KeepAwake>.fromOpaque(context).takeUnretainedValue().refreshEnvironment()
            }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
    }

    isolated deinit { shutdown() }

    var manualUntil: Date? { store.manualUntil }
    var triggeringApp: String? { store.triggeringApp }
    var isActive: Bool { store.isActive }
    var statusText: String { store.statusText }
    var statusTitle: String { store.statusTitle }

    func apply(_ config: KeepAwakeConfig) {
        store.send(.configurationChanged(config, onACPower: isOnACPower(), triggeringApp: runningTriggerApp(config)))
    }
    func start(minutes: Int?) { store.send(.start(minutes: minutes)) }
    func stop() { store.send(.stop) }
    func toggle() { manualUntil == nil ? start(minutes: store.config.defaultDurationMinutes) : stop() }

    func shutdown() {
        store.send(.shutdown)
        assertions.shutdown()
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes)
            CFRunLoopSourceInvalidate(powerSource)
        }
        powerSource = nil
    }

    private func refreshEnvironment() {
        store.send(.environmentChanged(onACPower: isOnACPower(), triggeringApp: runningTriggerApp(store.config)))
    }
    private func runningTriggerApp(_ config: KeepAwakeConfig) -> String? {
        let app = NSWorkspace.shared.runningApplications.first {
            !$0.isTerminated && $0.bundleIdentifier.map(config.activateForApps.contains) == true
        }
        return app?.localizedName ?? app?.bundleIdentifier
    }
    private func isOnACPower() -> Bool {
        guard let source = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() else { return true }
        return source as String == "AC Power"
    }
}
