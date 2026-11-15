import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func eventTapRoutesRootShortcutAndSwallowsRepeatAndRelease() async throws {
        _ = NSApplication.shared
        let controller = ShortcutController()
        let clipboard = FloatingPanel(size: NSSize(width: 200, height: 100)) { Text("Clipboard fixture") }
        let root = FloatingPanel(size: NSSize(width: 200, height: 100)) { Text("Root fixture") }
        var calls = 0
        controller.onPanelShortcut = { event in
            PanelShortcutRouter.handleRootSearchShortcut(event, in: NSApp.keyWindow)
        }
        defer {
            PanelShortcutRouter.onRootSearchShortcut(combo: { nil }, action: {})
            clipboard.close()
            root.close()
        }
        clipboard.present()
        #expect(clipboard.isKeyWindow)
        let down = try escapeEvent(down: true)
        let handled = await awaitRootShortcut { completed in
            PanelShortcutRouter.onRootSearchShortcut(combo: { KeyCombo("cmd+escape") }) {
                calls += 1
                root.present()
                completed()
            }
            return controller.handle(down, type: .keyDown)
        }
        #expect(handled)
        #expect(!clipboard.isVisible)
        #expect(root.isVisible)
        #expect(calls == 1)
        down.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        #expect(controller.handle(down, type: .keyDown))
        #expect(root.isVisible)
        #expect(calls == 1)
        let up = try escapeEvent(down: false)
        up.flags = [] // Command can be released before Escape.
        #expect(controller.handle(up, type: .keyUp))
        #expect(!controller.handle(up, type: .keyUp))
    }

    @Test func eventTapLeavesNormalWindowsAndPausedOrDisabledShortcutsAlone() throws {
        _ = NSApplication.shared
        let controller = ShortcutController()
        let panel = FloatingPanel(size: NSSize(width: 200, height: 100)) { Text("Fixture") }
        let regular = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        defer {
            PanelShortcutRouter.onRootSearchShortcut(combo: { nil }, action: {})
            panel.close()
            regular.orderOut(nil)
        }
        let down = try escapeEvent(down: true)
        PanelShortcutRouter.onRootSearchShortcut(combo: { KeyCombo("cmd+escape") }) { Issue.record("Unexpected root navigation") }
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(down, in: nil))
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(down, in: panel)) // Hidden panel.
        regular.makeKeyAndOrderFront(nil)
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(down, in: regular))
        panel.present()
        controller.onPanelShortcut = { PanelShortcutRouter.handleRootSearchShortcut($0, in: panel) }
        controller.isPaused = true
        #expect(!controller.handle(down, type: .keyDown))
        controller.isPaused = false
        PanelShortcutRouter.onRootSearchShortcut(combo: { nil }) { Issue.record("Disabled shortcut fired") }
        #expect(!controller.handle(down, type: .keyDown))
        #expect(panel.isVisible)
    }

    private func escapeEvent(down: Bool) throws -> CGEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: KeyCode.escape, keyDown: down))
        event.flags = .maskCommand
        return event
    }
}
