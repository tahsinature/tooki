import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func disablingRememberPositionPreservesSearchFiltersAndDrafts() async throws {
        _ = NSApplication.shared
        let now = Date()
        let entries = (0..<30).map {
            Snippet(name: "Entry \($0)", collection: "Work", text: "Text", createdAt: now.addingTimeInterval(-Double($0)))
        }
        let document = JSONDocument(
            fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), initialValue: entries
        )
        let preference = JSONDocument(
            fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), initialValue: TookiConfig()
        )
        let controller = SnippetPanelController(snippets: document, usage: SnippetUsage(), inserter: SnippetInserter())
        controller.remembersPosition = { preference.value.panelNavigation.rememberToolPosition }
        controller.show()
        defer { controller.close() }
        let hosting = try #require(controller.panel?.contentView as? NSHostingView<SnippetPanelView>)
        let model = hosting.rootView.model
        model.query = "Entry"
        model.collectionFilter = "Work"
        model.selectedID = entries.last?.id
        try? await Task.sleep(for: .milliseconds(200))
        let scroll = try #require(positionScrollView(in: hosting))
        #expect(scroll.documentVisibleRect.minY > 100)
        controller.close()
        #expect(controller.resume())
        #expect(model.selectedSnippet?.id == entries.last?.id)

        // The live preference affects a panel that already exists.
        preference.value.panelNavigation.rememberToolPosition = false
        controller.close()
        #expect(controller.resume())
        try? await Task.sleep(for: .milliseconds(200))
        #expect(controller.panel?.contentView === hosting)
        #expect(model.selectedSnippet?.id == entries.first?.id)
        #expect(scroll.documentVisibleRect.minY <= 1)
        #expect(model.query == "Entry")
        #expect(model.collectionFilter == "Work")

        // Reset even when selection is already first but the pointer scrolled elsewhere.
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 150))
        scroll.reflectScrolledClipView(scroll.contentView)
        controller.close()
        #expect(controller.resume())
        try? await Task.sleep(for: .milliseconds(200))
        #expect(scroll.documentVisibleRect.minY <= 1)

        model.startCreating()
        model.form?.draft.name = "Unfinished"
        controller.close()
        #expect(controller.resume())
        #expect(model.form?.draft.name == "Unfinished")
        #expect(model.form?.isNew == true)
        #expect(model.collectionFilter == "Work")
    }

    @Test func positionResetAppliesToSearchEmojiClipboardAndShelf() throws {
        _ = NSApplication.shared
        let search = SearchPanelController()
        search.remembersPosition = { false }
        let entries = (0..<5).map {
            SearchItem(id: "\($0)", title: "Entry \($0)", kind: "Command", group: .commands,
                       icon: .symbol("gear"), actionTitle: "Run", run: {})
        }
        search.show(.everything, items: entries)
        defer { search.close() }
        let searchModel = try #require((search.panel?.contentView as? NSHostingView<SearchView>)?.rootView.model)
        searchModel.query = "Entry"
        searchModel.selection = 3
        search.close()
        #expect(search.resume(.everything))
        #expect(searchModel.selection == 0)
        #expect(searchModel.query == "Entry")

        let emoji = EmojiPanelController()
        emoji.remembersPosition = { false }
        emoji.show()
        defer { emoji.close() }
        let emojiModel = try #require((emoji.panel?.contentView as? NSHostingView<EmojiPanelView>)?.rootView.model)
        emojiModel.query = "face"
        emojiModel.selection = 3
        emoji.close()
        #expect(emoji.resume())
        #expect(emojiModel.selection == 0)
        #expect(emojiModel.query == "face")

        let clipboard = ClipboardPanelController(history: ClipboardHistory(), shelves: ShelfWindows(library: ShelfLibrary()))
        clipboard.remembersPosition = { false }
        clipboard.show()
        defer { clipboard.close() }
        let clipboardModel = try #require((clipboard.panel?.contentView as? NSHostingView<ClipboardPanelView>)?.rootView.model)
        clipboardModel.query = "kept query"
        clipboardModel.typeFilter = .text
        let clipboardRevision = clipboardModel.navigation.resultsRevision
        clipboard.close()
        #expect(clipboard.resume())
        #expect(clipboardModel.navigation.resultsRevision == clipboardRevision + 1)
        #expect(clipboardModel.query == "kept query")
        #expect(clipboardModel.typeFilter == .text)

        let shelf = ShelfManagerController(windows: ShelfWindows(library: ShelfLibrary()))
        shelf.remembersPosition = { false }
        shelf.show(library: ShelfLibrary())
        defer { shelf.close() }
        let shelfModel = try #require((shelf.panel?.contentView as? NSHostingView<ShelfManagerView>)?.rootView.model)
        shelfModel.query = "kept query"
        let shelfRevision = shelfModel.navigation.resultsRevision
        shelf.close()
        #expect(shelf.resume())
        #expect(shelfModel.navigation.resultsRevision == shelfRevision + 1)
        #expect(shelfModel.query == "kept query")
    }

    private func positionScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { positionScrollView(in: $0) }.first
    }
}
