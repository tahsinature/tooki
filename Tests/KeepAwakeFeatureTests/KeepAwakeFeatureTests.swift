import ComposableArchitecture
import Foundation
import KeepAwakeFeature
import Testing
import TookiKit

@MainActor
struct KeepAwakeFeatureTests {
    private func store(clock: TestClock<Duration>, active: @escaping @Sendable (KeepAwakeMode?) async -> Bool = { $0 != nil })
        -> TestStore<KeepAwakeFeature.State, KeepAwakeFeature.Action> {
        let store = TestStore(initialState: KeepAwakeFeature.State()) { KeepAwakeFeature() } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .incrementing
            $0.keepAwakeClient = KeepAwakeClient(setAssertion: active)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    @Test func finiteSessionExpiresPreciselyAndReleasesTheAssertion() async {
        let clock = TestClock()
        let store = store(clock: clock)
        await store.send(.start(minutes: 1))
        await store.receive(\.assertionResult)
        #expect(store.state.isActive)
        await clock.advance(by: .seconds(59))
        #expect(store.state.manualUntil != nil)
        await clock.advance(by: .seconds(1))
        await store.receive(\.expired)
        await store.receive(\.assertionResult)
        #expect(!store.state.isActive)
        #expect(store.state.manualUntil == nil)
        await store.finish()
    }

    @Test func batteryRestrictionPausesAndResumesAnExistingRequest() async {
        let clock = TestClock()
        let store = store(clock: clock)
        var config = KeepAwakeConfig()
        config.onlyOnPower = true
        await store.send(.configurationChanged(config, onACPower: false, triggeringApp: nil))
        await store.send(.start(minutes: nil))
        #expect(store.state.isPausedByPower)
        #expect(store.state.statusText == "Paused while on battery power")
        #expect(!store.state.isActive)
        await store.send(.environmentChanged(onACPower: true, triggeringApp: nil))
        await store.receive(\.assertionResult)
        #expect(store.state.isActive)
        await store.send(.environmentChanged(onACPower: false, triggeringApp: nil))
        await store.receive(\.assertionResult)
        #expect(store.state.isPausedByPower)
        await store.send(.shutdown)
        await store.finish()
    }

    @Test func automaticRuleSurvivesManualStopAndModeChangesReplaceAssertion() async {
        let clock = TestClock()
        let modes = LockIsolated<[KeepAwakeMode?]>([])
        let store = store(clock: clock) { mode in modes.withValue { $0.append(mode) }; return mode != nil }
        await store.send(.environmentChanged(onACPower: true, triggeringApp: "Editor"))
        await store.receive(\.assertionResult)
        await store.send(.start(minutes: 0))
        await store.send(.stop)
        #expect(store.state.isActive)
        var config = KeepAwakeConfig()
        config.mode = .system
        await store.send(.configurationChanged(config, onACPower: true, triggeringApp: "Editor"))
        await store.receive(\.assertionResult)
        #expect(modes.value == [.display, .system])
        await store.send(.environmentChanged(onACPower: true, triggeringApp: nil))
        await store.receive(\.assertionResult)
        #expect(store.state.statusText == "Off")
        await store.finish()
    }

    @Test func failedAssertionIsHonestAndRetriesWithControlledTime() async {
        let clock = TestClock()
        let succeeds = LockIsolated(false)
        let store = store(clock: clock) { mode in mode != nil && succeeds.value }
        await store.send(.start(minutes: nil))
        await store.receive(\.assertionResult)
        #expect(store.state.assertionFailed)
        #expect(!store.state.isActive)
        succeeds.setValue(true)
        await clock.advance(by: .seconds(15))
        await store.receive(\.retry)
        await store.receive(\.assertionResult)
        #expect(store.state.isActive)
        #expect(!store.state.assertionFailed)
        await store.send(.shutdown)
        await store.finish()
    }

    @Test func restartingSessionCancelsItsOldExpiry() async {
        let clock = TestClock()
        let store = store(clock: clock)
        await store.send(.start(minutes: 1))
        await store.receive(\.assertionResult)
        await clock.advance(by: .seconds(30))
        await store.send(.start(minutes: 2))
        await clock.advance(by: .seconds(30))
        #expect(store.state.isActive)
        await store.send(.stop)
        await store.receive(\.assertionResult)
        await clock.advance(by: .seconds(120))
        #expect(store.state.manualUntil == nil)
        await store.finish()
    }
}
