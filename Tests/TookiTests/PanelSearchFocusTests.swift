import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

// Keep window tests in the existing serialized suite so they cannot steal each other's focus.
extension PanelRestorationTests {
    @Test func searchFieldsReceiveTypingOnFirstOpenAndAfterReopening() async throws {
        _ = NSApplication.shared
        let root = SearchPanelController()
        let clipboard = ClipboardPanelController(history: ClipboardHistory(), shelves: ShelfWindows(library: ShelfLibrary()))
        let shelves = ShelfManagerController(windows: ShelfWindows(library: ShelfLibrary()))
        let document = JSONDocument(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
                                    initialValue: Snippet.examples)
        let snippets = SnippetPanelController(snippets: document, usage: SnippetUsage(), inserter: SnippetInserter())
        let emoji = EmojiPanelController()

        let panels: [(String, () -> FloatingPanel?, () -> String)] = [
            ("Root Search", { root.show(.everything, items: []); return root.panel }, {
                (root.panel?.contentView as? NSHostingView<SearchView>)?.rootView.model.query ?? ""
            }),
            ("Clipboard", { clipboard.show(); return clipboard.panel }, {
                (clipboard.panel?.contentView as? NSHostingView<ClipboardPanelView>)?.rootView.model.query ?? ""
            }),
            ("Shelf Manager", { shelves.show(library: ShelfLibrary()); return shelves.panel }, {
                (shelves.panel?.contentView as? NSHostingView<ShelfManagerView>)?.rootView.model.query ?? ""
            }),
            ("Snippets", { snippets.show(); return snippets.panel }, {
                (snippets.panel?.contentView as? NSHostingView<SnippetPanelView>)?.rootView.model.query ?? ""
            }),
            ("Emoji", { emoji.show(); return emoji.panel }, {
                (emoji.panel?.contentView as? NSHostingView<EmojiPanelView>)?.rootView.model.query ?? ""
            }),
        ]

        for (name, show, query) in panels {
            let panel = try #require(show())
            defer { panel.close() }
            await waitForEditor(in: panel)
            let editor = try #require(panel.firstResponder as? NSTextView, "\(name) must focus its search on opening")
            editor.insertText("first", replacementRange: editor.selectedRange())
            await settleFocus()
            #expect(query() == "first", "\(name) must send typing to its search")

            // Simulate leaving keyboard focus in another control before the retained panel closes.
            let otherField = NSTextField(string: "Other control")
            otherField.frame = CGRect(x: 20, y: 60, width: 140, height: 24)
            panel.contentView?.addSubview(otherField)
            #expect(panel.makeFirstResponder(otherField))
            await settleFocus()
            #expect((panel.firstResponder as? NSTextView)?.delegate as AnyObject? === otherField,
                    "Search must not steal focus during ordinary use")
            panel.close()
            panel.present(restoring: true)
            await settleFocus()
            let restoredEditor = try #require(panel.firstResponder as? NSTextView)
            #expect(restoredEditor.delegate as AnyObject? !== otherField,
                    "\(name) must return to search when reopened")
            #expect(query() == "first", "Reopening must preserve the query")
            restoredEditor.insertText("second", replacementRange: NSRange(location: 0, length: restoredEditor.string.utf16.count))
            await settleFocus()
            #expect(query() == "second", "\(name) must receive typing after reopening")
            otherField.removeFromSuperview()
        }
    }

    @Test func actionsKeepFocusOnReopenAndReturnItToSearchWhenDismissed() async throws {
        _ = NSApplication.shared
        let controller = SearchPanelController()
        let item = SearchItem(id: "test", title: "Test", kind: "Command", group: .commands,
                              icon: .symbol("gear"), actionTitle: "Run", run: {})
        controller.show(.everything, items: [item])
        defer { controller.close() }
        let panel = try #require(controller.panel)
        let hosting = try #require(panel.contentView as? NSHostingView<SearchView>)
        let model = hosting.rootView.model
        await settleFocus()
        model.isShowingActions = true
        await settleFocus()
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.insertText("menu", replacementRange: editor.selectedRange())
        await settleFocus()
        #expect(model.menuQuery == "menu")
        #expect(model.query.isEmpty)

        controller.close()
        #expect(controller.resume())
        await settleFocus()
        let popupEditor = try #require(panel.firstResponder as? NSTextView)
        popupEditor.insertText("again", replacementRange: NSRange(location: 0, length: popupEditor.string.utf16.count))
        await settleFocus()
        #expect(model.menuQuery == "again")
        #expect(model.query.isEmpty)

        model.isShowingActions = false
        await settleFocus()
        let searchEditor = try #require(panel.firstResponder as? NSTextView)
        searchEditor.insertText("search", replacementRange: searchEditor.selectedRange())
        await settleFocus()
        #expect(model.query == "search")
    }

    @Test func filterReceivesTypingAndReturnsFocusToSearchAfterPicking() async throws {
        _ = NSApplication.shared
        let controller = SearchPanelController()
        controller.show(.everything, items: [])
        defer { controller.close() }
        let panel = try #require(controller.panel)
        let hosting = try #require(panel.contentView as? NSHostingView<SearchView>)
        await settleFocus()
        let openFilter = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "p",
            charactersIgnoringModifiers: "p", isARepeat: false, keyCode: 35
        ))
        panel.sendEvent(openFilter)
        await settleFocus()
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.insertText("applications", replacementRange: editor.selectedRange())
        await settleFocus()
        #expect(hosting.rootView.model.query.isEmpty)
        let pickFilter = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        panel.sendEvent(pickFilter)
        await settleFocus()
        #expect(hosting.rootView.model.groupFilter == .applications)
        let searchEditor = try #require(panel.firstResponder as? NSTextView)
        searchEditor.insertText("search", replacementRange: searchEditor.selectedRange())
        await settleFocus()
        #expect(hosting.rootView.model.query == "search")
    }

    @Test func reopeningSnippetDraftKeepsItsEditorAndText() async throws {
        _ = NSApplication.shared
        let document = JSONDocument(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
                                    initialValue: Snippet.examples)
        let controller = SnippetPanelController(snippets: document, usage: SnippetUsage(), inserter: SnippetInserter())
        controller.show(creating: true)
        defer { controller.close() }
        let panel = try #require(controller.panel)
        let hosting = try #require(panel.contentView as? NSHostingView<SnippetPanelView>)
        await settleFocus()
        let editor = try #require(snippetEditor(in: hosting))
        #expect(panel.makeFirstResponder(editor))
        editor.insertText("Unfinished draft", replacementRange: editor.selectedRange())
        await settleFocus()
        controller.close()
        #expect(controller.resume())
        await settleFocus()
        #expect(panel.firstResponder === editor)
        #expect(hosting.rootView.model.form?.draft.text == "Unfinished draft")
    }

    private func snippetEditor(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView, !text.isFieldEditor, text.isEditable { return text }
        return view.subviews.lazy.compactMap { snippetEditor(in: $0) }.first
    }

    private func waitForEditor(in panel: FloatingPanel) async {
        for _ in 0..<100 {
            if panel.firstResponder is NSTextView { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Let AppKit and SwiftUI finish their main-actor work between interactions.
    private func settleFocus() async {
        try? await Task.sleep(for: .milliseconds(100))
    }
}
