import AppKit
import TookiKit

/// Routes navigation shortcuts before either panel type handles its own keys.
@MainActor
enum PanelShortcutRouter {
    private static var rootCombo: () -> KeyCombo? = { nil }
    private static var openRoot: () -> Void = {}

    @discardableResult
    static func hideShelf(_ window: NSWindow?) -> Bool {
        guard let shelf = window as? ShelfPanel else { return false }
        shelf.onHide()
        return true
    }

    static func onRootSearchShortcut(
        combo: @escaping () -> KeyCombo?, action: @escaping () -> Void
    ) {
        rootCombo = combo
        openRoot = action
    }

    /// A nonactivating panel can own keyboard focus while command key equivalents bypass its event queue.
    /// Route from the shared event tap before AppKit dispatches those equivalents to the active app.
    static func handleRootSearchShortcut(_ event: CGEvent, in window: NSWindow?) -> Bool {
        guard let window, window.isVisible, window.isKeyWindow,
              let nativeEvent = NSEvent(cgEvent: event) else { return false }
        return handleRootSearchShortcut(nativeEvent, in: window)
    }

    /// Called by the receiving window, including when AppKit dispatches a key equivalent directly.
    static func handleRootSearchShortcut(_ event: NSEvent, in window: NSWindow) -> Bool {
        return handleRootSearchShortcut(event, in: window, combo: rootCombo(), action: openRoot)
    }

    @discardableResult
    static func handleRootSearchShortcut(
        _ event: NSEvent, in window: NSWindow?, combo: KeyCombo?, action: @escaping () -> Void
    ) -> Bool {
        guard event.type == .keyDown,
              window is FloatingPanel || window is ShelfPanel,
              let combo,
              KeyCombo(keyCode: event.keyCode, modifiers: KeyCombo.Modifiers(event.modifierFlags)) == combo
        else { return false }
        if !event.isARepeat {
            if !hideShelf(window) { window?.close() }
            // Finish the old window's key event and focus teardown before presenting its replacement.
            Task { @MainActor in action() }
        }
        return true
    }
}
