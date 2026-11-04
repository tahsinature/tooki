import CoreGraphics

/// Something that wants to see (and possibly swallow) keyboard events.
@MainActor
protocol KeyEventHandler: AnyObject {
    /// Return `true` to swallow the event so no app receives it.
    func handle(_ event: CGEvent, type: CGEventType) -> Bool
}

/// A single system-wide event tap shared by all modules.
/// Requires the Accessibility permission.
@MainActor
final class KeyboardMonitor {
    private let handlers: [KeyEventHandler]
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    init(handlers: [KeyEventHandler]) {
        self.handlers = handlers
    }

    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
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
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.tap = nil
        self.runLoopSource = nil
    }

    fileprivate func process(_ type: CGEventType, _ event: CGEvent) -> Bool {
        // macOS disables slow taps; turn it straight back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if SyntheticEvent.isSynthetic(event) { return false }
        return handlers.contains { $0.handle(event, type: type) }
    }
}

private func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap is attached to the main run loop, so this always runs on the main thread.
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated { monitor.process(type, event) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
