import AppKit
import CoreGraphics
import TookiKit

/// Runs global shortcuts. Placed after the Hyper key handler,
/// so Caps Lock combos arrive here already carrying ⌃⌥⇧⌘.
@MainActor
final class ShortcutController: KeyEventHandler {
    var onAction: (HotkeyAction) -> Void = { _ in }
    /// Paused while the settings window records a new shortcut.
    var isPaused = false

    private var actionsByCombo: [KeyCombo: HotkeyAction] = [:]
    // Key ups of handled shortcuts are swallowed too, so apps never see half a key press.
    private var swallowedKeyCodes: Set<Int64> = []

    func apply(_ shortcuts: [Shortcut]) {
        actionsByCombo = [:]
        for shortcut in shortcuts where shortcut.enabled {
            guard let combo = KeyCombo(shortcut.keys), let action = HotkeyAction(shortcut.action) else { continue }
            if actionsByCombo[combo] == nil { actionsByCombo[combo] = action }
        }
    }

    func handle(_ event: CGEvent, type: CGEventType) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp { return swallowedKeyCodes.remove(keyCode) != nil }
        guard type == .keyDown, !isPaused,
              let combo = KeyCombo(keyCode: UInt16(keyCode), modifiers: KeyCombo.Modifiers(event.flags)),
              let action = actionsByCombo[combo]
        else { return false }

        swallowedKeyCodes.insert(keyCode)
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { onAction(action) }
        return true
    }
}

extension KeyCombo.Modifiers {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
}
