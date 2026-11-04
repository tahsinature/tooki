import CoreGraphics
import Foundation
import TookiKit

/// Turns Caps Lock (remapped to F18) into ⌃⌥⇧⌘ while held,
/// runs Tooki's own Hyper shortcuts, and toggles Caps Lock when tapped alone.
@MainActor
final class HyperKeyController: KeyEventHandler {
    var onAction: (HotkeyAction) -> Void = { _ in }

    private static let hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    private static let tapThreshold: TimeInterval = 0.3

    private var config = HyperKeyConfig()
    private var actionsByKeyCode: [Int64: HotkeyAction] = [:]
    // Starts as true so the first apply clears a mapping left over from a crash.
    private var isRemapped = true
    private var isHeld = false
    private var wasUsedAsModifier = false
    private var pressedAt = Date.distantPast

    /// The remap is only turned on while the event tap runs; otherwise Caps Lock would do nothing.
    func apply(_ config: HyperKeyConfig, isMonitoring: Bool) {
        self.config = config
        actionsByKeyCode = [:]
        for binding in config.bindings {
            if let keyCode = KeyCode.forKey(binding.key), let action = HotkeyAction(binding.action) {
                actionsByKeyCode[Int64(keyCode)] = action
            }
        }
        setRemapped(config.enabled && isMonitoring)
    }

    func shutdown() {
        setRemapped(false)
    }

    func handle(_ event: CGEvent, type: CGEventType) -> Bool {
        guard config.enabled, type == .keyDown || type == .keyUp else { return false }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if keyCode == Int64(KeyCode.f18) {
            handleHyperKey(isDown: type == .keyDown, isRepeat: isRepeat)
            return true
        }
        guard isHeld else { return false }
        wasUsedAsModifier = true

        if let action = actionsByKeyCode[keyCode] {
            if type == .keyDown, !isRepeat { onAction(action) }
            return true
        }
        event.flags.formUnion(Self.hyperFlags)
        return false
    }

    private func handleHyperKey(isDown: Bool, isRepeat: Bool) {
        if isDown {
            guard !isRepeat else { return }
            isHeld = true
            wasUsedAsModifier = false
            pressedAt = Date()
        } else {
            isHeld = false
            let wasTap = !wasUsedAsModifier && Date().timeIntervalSince(pressedAt) < Self.tapThreshold
            if wasTap { CapsLockState.toggle() }
        }
    }

    private func setRemapped(_ remapped: Bool) {
        guard remapped != isRemapped else { return }
        CapsLockRemapper.setEnabled(remapped)
        isRemapped = remapped
        if !remapped { isHeld = false }
    }
}
