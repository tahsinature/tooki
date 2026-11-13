import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

@MainActor
@Suite(.serialized) struct PanelRestorationTests {
    private func item(_ id: String, title: String? = nil) -> SearchItem {
        SearchItem(id: id, title: title ?? id, kind: "Command", group: .commands,
                   icon: .symbol("gear"), actionTitle: "Run", run: {})
    }

    @Test func searchReopensTheSameViewWithItsQueryFilterAndSelection() throws {
        _ = NSApplication.shared
        let controller = SearchPanelController()
        controller.show(.everything, items: [item("first"), item("second")])
        defer { controller.close() }
        let panel = try #require(controller.panel)
        let hosting = try #require(panel.contentView as? NSHostingView<SearchView>)
        let model = hosting.rootView.model
        model.query = "s"
        model.groupFilter = .commands
        model.selection = 1
        let selectedID = model.selectedItem?.id
        panel.setFrameOrigin(CGPoint(x: 100, y: 100))
        let origin = panel.frame.origin

        // Blur and action-driven dismissal both use this same close path.
        controller.close()
        #expect(!controller.isShowing)
        #expect(controller.resume())
        #expect(controller.isShowing)
        #expect(controller.panel === panel)
        #expect(panel.contentView === hosting)
        #expect(panel.frame.origin == origin)
        #expect(model.query == "s")
        #expect(model.groupFilter == .commands)
        #expect(model.selectedItem?.id == selectedID)

        // Returning to root deliberately replaces the retained view and resets its state.
        controller.show(.everything, items: [item("first")])
        let freshHosting = try #require(controller.panel?.contentView as? NSHostingView<SearchView>)
        #expect(freshHosting !== hosting)
        #expect(freshHosting.rootView.model.query.isEmpty)
        #expect(freshHosting.rootView.model.groupFilter == nil)
    }

    @Test func snippetsRetainTheirDraftWhenHiddenAndReopened() throws {
        _ = NSApplication.shared
        let document = JSONDocument(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
                                    initialValue: Snippet.examples)
        let controller = SnippetPanelController(snippets: document, usage: SnippetUsage(), inserter: SnippetInserter())
        controller.show()
        defer { controller.close() }
        let hosting = try #require(controller.panel?.contentView as? NSHostingView<SnippetPanelView>)
        let model = hosting.rootView.model
        model.startCreating()
        model.form?.draft.name = "Unfinished draft"
        controller.close()
        controller.toggle()
        #expect(controller.panel?.contentView === hosting)
        #expect(model.form?.draft.name == "Unfinished draft")
        #expect(model.form?.isNew == true)
    }

    @Test func escapeClearsManagerThenRestoresParentQueryThenClearsRoot() throws {
        _ = NSApplication.shared
        let root = SearchPanelController()
        let clipboard = ClipboardPanelController(history: ClipboardHistory(), shelves: ShelfWindows(library: ShelfLibrary()))
        defer { root.close(); clipboard.close() }
        root.show(.everything, items: [item("clipboard")])
        let rootHosting = try #require(root.panel?.contentView as? NSHostingView<SearchView>)
        rootHosting.rootView.model.query = "clip"
        root.close()
        clipboard.onBack = { root.resume(.everything) }
        clipboard.show()
        let hosting = try #require(clipboard.panel?.contentView as? NSHostingView<ClipboardPanelView>)
        hosting.rootView.model.query = "tes"

        // SwiftUI's search field receives the first Esc.
        hosting.rootView.onCancel()
        #expect(hosting.rootView.model.query.isEmpty)
        #expect(clipboard.isShowing)
        #expect(!root.isShowing)

        // AppKit cancellation follows the same sequence regardless of field focus.
        clipboard.panel?.cancelOperation(nil)
        #expect(!clipboard.isShowing)
        #expect(root.isShowing)
        #expect(root.panel?.contentView === rootHosting)
        #expect(rootHosting.rootView.model.query == "clip")
        root.panel?.cancelOperation(nil)
        #expect(rootHosting.rootView.model.query.isEmpty)
        #expect(root.isShowing)
        rootHosting.rootView.onCancel()
        #expect(!root.isShowing)
    }

    @Test func commandEscapeBypassesTheFilteredManagerAndResetsRoot() throws {
        _ = NSApplication.shared
        let root = SearchPanelController()
        let clipboard = ClipboardPanelController(history: ClipboardHistory(), shelves: ShelfWindows(library: ShelfLibrary()))
        defer { root.close(); clipboard.close() }
        root.show(.everything, items: [item("clipboard")])
        let previousRoot = try #require(root.panel?.contentView as? NSHostingView<SearchView>)
        previousRoot.rootView.model.query = "clip"
        root.close()
        clipboard.show()
        let panel = try #require(clipboard.panel)
        let hosting = try #require(panel.contentView as? NSHostingView<ClipboardPanelView>)
        hosting.rootView.model.query = "tes"
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: KeyCode.escape
        ))
        #expect(PanelShortcutRouter.handleRootSearchShortcut(event, in: panel, combo: KeyCombo("cmd+escape")) {
            root.show(.everything, items: [item("clipboard")])
        })
        let freshRoot = try #require(root.panel?.contentView as? NSHostingView<SearchView>)
        #expect(!clipboard.isShowing)
        #expect(root.isShowing)
        #expect(freshRoot !== previousRoot)
        #expect(freshRoot.rootView.model.query.isEmpty)
        #expect(hosting.rootView.model.query == "tes")
        root.close()
        #expect(root.resume(.everything))
        #expect(root.panel?.contentView === freshRoot)
    }

    @Test func snippetEscapeClearsQueryBeforeReturningToRoot() throws {
        _ = NSApplication.shared
        let document = JSONDocument(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
                                    initialValue: Snippet.examples)
        let controller = SnippetPanelController(snippets: document, usage: SnippetUsage(), inserter: SnippetInserter())
        defer { controller.close() }
        var backCount = 0
        controller.onBack = { backCount += 1 }
        controller.show()
        let hosting = try #require(controller.panel?.contentView as? NSHostingView<SnippetPanelView>)
        hosting.rootView.model.query = "tes"
        controller.panel?.cancelOperation(nil)
        #expect(hosting.rootView.model.query.isEmpty)
        #expect(controller.isShowing)
        #expect(backCount == 0)
        hosting.rootView.onCancel()
        #expect(!controller.isShowing)
        #expect(backCount == 1)
    }

    @Test func focusedShelfUsesItsHideAction() {
        _ = NSApplication.shared
        let shelf = ShelfPanel(shelf: Shelf(name: "Test"), content: Text("Shelf"))
        defer { shelf.close() }
        var hideCount = 0
        shelf.onHide = { hideCount += 1 }
        #expect(PanelShortcutRouter.hideShelf(shelf))
        #expect(hideCount == 1)
        #expect(!PanelShortcutRouter.hideShelf(nil))
    }

    @Test func rootShortcutHidesTheShelfBeforeOpeningRootSearch() throws {
        _ = NSApplication.shared
        let shelf = ShelfPanel(shelf: Shelf(name: "Test"), content: Text("Shelf"))
        defer { shelf.close() }
        var calls: [String] = []
        shelf.onHide = { calls.append("hide") }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: shelf.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: KeyCode.escape
        ))
        #expect(PanelShortcutRouter.handleRootSearchShortcut(event, in: shelf, combo: KeyCombo("cmd+escape")) {
            calls.append("root")
        })
        #expect(calls == ["hide", "root"])
        calls = []
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(event, in: shelf, combo: KeyCombo("ctrl+r")) {
            calls.append("root")
        })
        #expect(calls.isEmpty)
        #expect(!PanelShortcutRouter.handleRootSearchShortcut(event, in: shelf, combo: nil) {})
    }

    @Test func refreshingSearchPreservesIdentityAndDropsRemovedResults() {
        let model = SearchModel(items: [item("first"), item("second")], placeholder: "Search", title: "Tooki",
                                icon: .symbol("magnifyingglass"), history: LaunchHistory())
        model.groupFilter = .commands
        model.selection = 1
        model.isShowingActions = true
        model.refresh(items: [item("new"), item("second", title: "Updated")], history: LaunchHistory())
        #expect(model.groupFilter == .commands)
        #expect(model.selectedItem?.id == "second")
        #expect(model.selectedItem?.title == "Updated")
        #expect(model.isShowingActions)
        model.refresh(items: [item("new")], history: LaunchHistory())
        #expect(model.selectedItem?.id == "new")
        model.refresh(items: [], history: LaunchHistory())
        #expect(model.selectedItem == nil)
    }
}
