import ComposableArchitecture
import Foundation
import TookiKit

@Reducer
public struct KeepAwakeFeature {
    @ObservableState
    public struct State: Equatable {
        public var config = KeepAwakeConfig()
        public var manualUntil: Date?
        public var triggeringApp: String?
        public var onACPower = true
        public var isActive = false
        public var isRequesting = false
        public var assertionFailed = false
        var requestedMode: KeepAwakeMode?
        var requestID: UUID?
        var expiryID: UUID?
        public init() {}

        public var isRequested: Bool { manualUntil != nil || triggeringApp != nil }
        public var isPausedByPower: Bool { isRequested && config.onlyOnPower && !onACPower }
        var desiredMode: KeepAwakeMode? { isRequested && !isPausedByPower ? config.mode : nil }
        public var statusTitle: String {
            if isPausedByPower { return "Keep Awake is paused" }
            if assertionFailed { return "Couldn't keep your Mac awake" }
            if isRequesting, isRequested { return "Starting Keep Awake…" }
            return isActive ? "Keeping your Mac awake" : "Your Mac can sleep normally"
        }
        public var statusText: String {
            if isPausedByPower { return "Paused while on battery power" }
            if assertionFailed { return "macOS couldn't start Keep Awake. Retrying…" }
            if let manualUntil {
                return manualUntil == .distantFuture ? "On until turned off" : "On until \(manualUntil.formatted(date: .omitted, time: .shortened))"
            }
            return triggeringApp.map { "On while \($0) is running" } ?? "Off"
        }
    }

    public enum Action: Equatable {
        case configurationChanged(KeepAwakeConfig, onACPower: Bool, triggeringApp: String?)
        case environmentChanged(onACPower: Bool, triggeringApp: String?)
        case start(minutes: Int?)
        case stop
        case expired(UUID)
        case assertionResult(UUID, Bool)
        case retry(UUID)
        case shutdown
    }
    @Dependency(\.keepAwakeClient) var client
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid
    private enum CancelID { case expiry, assertion, retry }
    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .configurationChanged(config, power, app):
                state.config = config
                state.onACPower = power
                state.triggeringApp = app
            case let .environmentChanged(power, app):
                state.onACPower = power
                state.triggeringApp = app
            case let .start(minutes):
                let id = uuid()
                state.expiryID = id
                if let minutes, minutes > 0 {
                    let seconds = Double(minutes) * 60
                    let deadline = date.now.addingTimeInterval(seconds)
                    state.manualUntil = deadline
                    return .merge(reconcile(&state), .run { [clock, date] send in
                        try await clock.sleep(for: .seconds(max(0, deadline.timeIntervalSince(date.now))))
                        await send(.expired(id))
                    }.cancellable(id: CancelID.expiry, cancelInFlight: true))
                }
                state.manualUntil = .distantFuture
                return .merge(.cancel(id: CancelID.expiry), reconcile(&state))
            case .stop:
                state.manualUntil = nil
                state.expiryID = nil
                return .merge(.cancel(id: CancelID.expiry), reconcile(&state))
            case let .expired(id):
                guard state.expiryID == id else { return .none }
                state.manualUntil = nil
                state.expiryID = nil
            case let .assertionResult(id, active):
                guard state.requestID == id else { return .none }
                state.isRequesting = false
                state.isActive = active && state.requestedMode != nil
                state.assertionFailed = state.requestedMode != nil && !active
                guard state.assertionFailed else { return .none }
                return .run { [clock] send in
                    try await clock.sleep(for: .seconds(15))
                    await send(.retry(id))
                }.cancellable(id: CancelID.retry, cancelInFlight: true)
            case let .retry(id):
                guard state.requestID == id else { return .none }
            case .shutdown:
                state = State()
                return .merge(.cancel(id: CancelID.expiry), .cancel(id: CancelID.assertion), .cancel(id: CancelID.retry))
            }
            return reconcile(&state)
        }
    }

    private func reconcile(_ state: inout State) -> Effect<Action> {
        let mode = state.desiredMode
        if state.requestedMode == mode, (state.isActive || state.isRequesting || mode == nil) { return .none }
        let id = uuid()
        state.requestedMode = mode
        state.requestID = id
        state.isRequesting = true
        state.assertionFailed = false
        if mode == nil { state.isActive = false }
        return .merge(.cancel(id: CancelID.retry), .run { [client] send in
            try Task.checkCancellation()
            let active = await client.setAssertion(mode)
            try Task.checkCancellation()
            await send(.assertionResult(id, active))
        }.cancellable(id: CancelID.assertion, cancelInFlight: true))
    }
}
