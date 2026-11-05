import CoreGraphics

/// Watches key presses at the last stop before they reach an app.
/// A press seen by `KeyboardMonitor` but never here was taken by someone along the way.
@MainActor
final class DeliveryTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    fileprivate var onDelivered: (_ keyCode: Int64, _ targetPID: pid_t) -> Void = { _, _ in }

    func start(onDelivered: @escaping (_ keyCode: Int64, _ targetPID: pid_t) -> Void) -> Bool {
        guard tap == nil else { return true }
        self.onDelivered = onDelivered
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1) << CGEventType.keyDown.rawValue,
            callback: deliveryTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        self.tap = nil
        self.runLoopSource = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

private func deliveryTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let deliveryTap = Unmanaged<DeliveryTap>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let pid = pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventTargetUnixProcessID))
    // Attached to the main run loop, so this runs on the main thread.
    MainActor.assumeIsolated {
        if type == .keyDown {
            deliveryTap.onDelivered(keyCode, pid)
        } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            deliveryTap.reenable()
        }
    }
    return Unmanaged.passUnretained(event)
}
