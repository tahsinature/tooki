import CoreGraphics
import Foundation

/// Delivers one synthetic mouse event to a menu bar icon and waits until the target app took it.
///
/// Ported from Thaw 2's `scrombleEvent` and `postEventWithBarrier`
/// (MenuBarItemManager+EventHelpers.swift, https://github.com/thaw-app/Thaw, GPLv3).
/// Null entry and exit marker events bracket the real one, and event taps watch it pass:
///
/// 1. The entry marker is posted to the app. A tap on the app swallows it and posts the
///    real event to the session, so the system routes it like a physical click.
/// 2. A tap on the session sees the real event go by. For `.scromble` it also posts the event
///    straight to the app; for `.barrier` it posts the exit marker.
/// 3. For `.scromble`, a tap on the app sees the event arrive and posts the exit marker.
/// 4. The first tap swallows the exit marker, which means delivery finished.
@MainActor
final class MenuBarEventRelay {
    enum Delivery {
        /// Through the session only. Used for clicks.
        case barrier
        /// Through the session and then straight to the app. Used for moves.
        case scromble
    }

    private let event: CGEvent
    private let pid: pid_t
    private let delivery: Delivery
    private let entryMarker: CGEvent
    private let exitMarker: CGEvent
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// Returns `false` when the event taps can't be created or the app didn't respond in time.
    static func post(_ event: CGEvent, to pid: pid_t, delivery: Delivery, timeout: Duration = .milliseconds(500)) async -> Bool {
        guard let entryMarker = MenuBarItemEvents.nullEvent(), let exitMarker = MenuBarItemEvents.nullEvent() else { return false }
        let relay = MenuBarEventRelay(event: event, pid: pid, delivery: delivery, entryMarker: entryMarker, exitMarker: exitMarker)
        return await relay.run(timeout: timeout)
    }

    private init(event: CGEvent, pid: pid_t, delivery: Delivery, entryMarker: CGEvent, exitMarker: CGEvent) {
        self.event = event
        self.pid = pid
        self.delivery = delivery
        self.entryMarker = entryMarker
        self.exitMarker = exitMarker
    }

    private func run(timeout: Duration) async -> Bool {
        guard installTaps() else {
            removeTaps()
            return false
        }
        defer { removeTaps() }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            entryMarker.postToPid(pid)
            timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                if !Task.isCancelled { finish(delivered: false) }
            }
        }
    }

    private func finish(delivered: Bool) {
        timeoutTask?.cancel()
        continuation?.resume(returning: delivered)
        continuation = nil
    }

    // MARK: Taps

    fileprivate enum Role {
        /// On the app, swallowing our entry and exit markers.
        case appNullEvents
        /// On the session, after every other tap.
        case session
        /// On the app, watching the real event arrive. Only for `.scromble`.
        case app
    }

    /// What an event tap's callback receives, to know which relay and tap it belongs to.
    fileprivate final class Tap {
        unowned let relay: MenuBarEventRelay
        let role: Role
        var port: CFMachPort?
        var source: CFRunLoopSource?

        init(relay: MenuBarEventRelay, role: Role) {
            self.relay = relay
            self.role = role
        }
    }

    private var taps: [Tap] = []

    private func installTaps() -> Bool {
        var roles: [Role] = [.appNullEvents, .session]
        if delivery == .scromble { roles.append(.app) }
        return roles.allSatisfy(addTap)
    }

    private func addTap(_ role: Role) -> Bool {
        let tap = Tap(relay: self, role: role)
        let info = Unmanaged.passUnretained(tap).toOpaque()
        let eventMask = CGEventMask(1) << (role == .appNullEvents ? CGEventType.null : event.type).rawValue
        tap.port = switch role {
        case .appNullEvents:
            CGEvent.tapCreateForPid(pid: pid, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: eventMask, callback: tapCallback, userInfo: info)
        case .session:
            CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                              eventsOfInterest: eventMask, callback: tapCallback, userInfo: info)
        case .app:
            CGEvent.tapCreateForPid(pid: pid, place: .headInsertEventTap, options: .listenOnly,
                                    eventsOfInterest: eventMask, callback: tapCallback, userInfo: info)
        }
        guard let port = tap.port, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            return false
        }
        tap.source = source
        taps.append(tap)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func removeTaps() {
        for tap in taps {
            if let port = tap.port {
                CGEvent.tapEnable(tap: port, enable: false)
                CFMachPortInvalidate(port)
            }
            if let source = tap.source {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        taps.removeAll()
    }

    /// Returns `true` to swallow the event.
    fileprivate func handle(_ incoming: CGEvent, type: CGEventType, at role: Role) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            taps.compactMap(\.port).forEach { CGEvent.tapEnable(tap: $0, enable: true) }
            return false
        }
        switch role {
        case .appNullEvents where Self.isSame(incoming, as: entryMarker):
            event.post(tap: .cgSessionEventTap)
            return true
        case .appNullEvents where Self.isSame(incoming, as: exitMarker):
            finish(delivered: true)
            return true
        case .session where Self.isSame(incoming, as: event):
            switch delivery {
            case .barrier: exitMarker.postToPid(pid)
            case .scromble: event.postToPid(pid)
            }
        case .app where Self.isSame(incoming, as: event):
            exitMarker.postToPid(pid)
        default:
            break
        }
        return false
    }

    private static func isSame(_ first: CGEvent, as second: CGEvent) -> Bool {
        first.getIntegerValueField(.eventSourceUserData) == second.getIntegerValueField(.eventSourceUserData)
    }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, info in
    guard let info else { return Unmanaged.passUnretained(event) }
    // The taps run on the main run loop, so the callback is already on the main thread.
    nonisolated(unsafe) let tap = Unmanaged<MenuBarEventRelay.Tap>.fromOpaque(info).takeUnretainedValue()
    nonisolated(unsafe) let incoming = event
    let swallow = MainActor.assumeIsolated { tap.relay.handle(incoming, type: type, at: tap.role) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
