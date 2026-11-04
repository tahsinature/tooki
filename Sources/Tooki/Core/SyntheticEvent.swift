import CoreGraphics

/// Key presses that Tooki itself sends. They are tagged so the keyboard monitor ignores them.
enum SyntheticEvent {
    private static let marker: Int64 = 0x7007_C1

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    static func press(_ keyCode: UInt16, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .privateState)
        source?.userData = marker
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}
