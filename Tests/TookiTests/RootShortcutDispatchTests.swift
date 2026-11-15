import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test(arguments: [false, true])
    func rootShortcutUsesReceivingWindowFromBothClipboardEntryPaths(openedFromSearch: Bool) async throws {
        _ = NSApplication.shared
        let root = SearchPanelController()
        let clipboard = ClipboardPanelController(history: ClipboardHistory(initialItems: [ClipboardItem(text: "Fixture")]),
                                                 shelves: ShelfWindows(library: ShelfLibrary()))
        let item = SearchItem(id: "clipboard", title: "Clipboard", kind: "Command", group: .commands,
                              icon: .symbol("doc.on.clipboard"), actionTitle: "Open", run: {})
        defer {
            PanelShortcutRouter.onRootSearchShortcut(combo: { nil }, action: {})
            root.close()
            clipboard.close()
        }
        if openedFromSearch {
            root.show(.everything, items: [item])
            (root.panel?.contentView as? NSHostingView<SearchView>)?.rootView.model.query = "clip"
            root.close()
        }
        clipboard.show()
        let panel = try #require(clipboard.panel)
        let model = try #require((panel.contentView as? NSHostingView<ClipboardPanelView>)?.rootView.model)
        model.query = "Fixture"
        model.actions.open()
        // Command shortcuts can arrive directly through AppKit's key-equivalent path.
        let event = try rootEvent(in: panel)
        let handled = await awaitRootShortcut { completed in
            PanelShortcutRouter.onRootSearchShortcut(combo: { KeyCombo("cmd+escape") }) {
                #expect(!clipboard.isShowing)
                root.show(.everything, items: [item])
                completed()
            }
            let handled = panel.performKeyEquivalent(with: event)
            #expect(!root.isShowing)
            return handled
        }
        #expect(handled)
        #expect(!clipboard.isShowing)
        #expect(root.isShowing)
        #expect((root.panel?.contentView as? NSHostingView<SearchView>)?.rootView.model.query.isEmpty == true)
        #expect(model.query == "Fixture")
    }

    @Test func rootShortcutAlsoRoutesSendEventAndFocusedShelfAndReadsLiveConfiguration() async throws {
        _ = NSApplication.shared
        var combo: KeyCombo? = KeyCombo("ctrl+r")
        var calls: [String] = []
        PanelShortcutRouter.onRootSearchShortcut(combo: { combo }) { calls.append("root") }
        defer { PanelShortcutRouter.onRootSearchShortcut(combo: { nil }, action: {}) }
        let panel = FloatingPanel(size: NSSize(width: 200, height: 100)) { Text("Fixture") }
        defer { panel.close() }
        let event = try rootEvent(in: panel)
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(event, in: panel))
        combo = KeyCombo("cmd+escape")
        var closed = false
        panel.onClose = { closed = true }
        panel.onEscape = {}
        #expect(await awaitRootShortcut { completed in
            PanelShortcutRouter.onRootSearchShortcut(combo: { combo }) { calls.append("root"); completed() }
            panel.sendEvent(event)
            return closed
        })
        #expect(calls == ["root"])
        let shelf = ShelfPanel(shelf: Shelf(name: "Fixture"), content: Text("Fixture"))
        defer { shelf.close() }
        shelf.onHide = { calls.append("hide") }
        let shelfEvent = try rootEvent(in: shelf)
        #expect(await awaitRootShortcut { completed in
            PanelShortcutRouter.onRootSearchShortcut(combo: { combo }) { calls.append("root"); completed() }
            return shelf.performKeyEquivalent(with: shelfEvent)
        })
        #expect(calls == ["root", "hide", "root"])
        combo = nil
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(event, in: panel))
    }

    private func rootEvent(in window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                     charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: KeyCode.escape))
    }
}
