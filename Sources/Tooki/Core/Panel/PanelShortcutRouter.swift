import AppKit
import TookiKit

/// Routes navigation shortcuts before either panel type handles its own keys.
@MainActor
enum PanelShortcutRouter {
    @discardableResult
    static func hideShelf(_ window: NSWindow?) -> Bool {
        guard let shelf = window as? ShelfPanel else { return false }
        shelf.onHide()
        return true
    }

    static func onRootSearchShortcut(
        combo: @escaping () -> KeyCombo?, action: @escaping () -> Void
    ) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleRootSearchShortcut(event, in: NSApp.keyWindow, combo: combo(), action: action) ? nil : event
        }
    }

    @discardableResult
    static func handleRootSearchShortcut(
        _ event: NSEvent, in window: NSWindow?, combo: KeyCombo?, action: () -> Void
    ) -> Bool {
        guard event.type == .keyDown,
              window is FloatingPanel || window is ShelfPanel,
              let combo,
              KeyCombo(keyCode: event.keyCode, modifiers: KeyCombo.Modifiers(event.modifierFlags)) == combo
        else { return false }
        if !event.isARepeat {
            if !hideShelf(window) { window?.close() }
            action()
        }
        return true
    }
}
