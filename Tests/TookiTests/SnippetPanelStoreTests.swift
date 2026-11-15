import AppKit
import Foundation
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func snippetStorePersistsEditsAndRefreshesAHiddenPanelWithoutLosingItsDraft() throws {
        _ = NSApplication.shared
        let entries = (0..<80).map { Snippet(name: "Entry \($0)", collection: "Work", text: "Body") }
        let document = JSONDocument(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), initialValue: entries)
        let controller = SnippetPanelController(snippets: document, usage: SnippetUsage(initialHistory: LaunchHistory()), inserter: SnippetInserter())
        withSnippetTestDependencies { controller.show() }
        defer { controller.close() }
        let hosting = try #require(controller.panel?.contentView as? NSHostingView<SnippetPanelView>)
        let model = hosting.rootView.model
        model.query = "Entry"
        model.collectionFilter = "Work"
        model.moveSelection(by: .max)
        #expect(model.selectedSnippet?.id == entries.last?.id)
        model.query = "Entry"
        #expect(model.selectedSnippet?.id == entries.last?.id)

        model.startEditingSelected()
        model.form?.draft.name = "Entry edited"
        #expect(model.saveDraft())
        #expect(document.value.last?.name == "Entry edited")
        #expect(model.selectedSnippet?.id == entries.last?.id)
        #expect(model.query == "Entry")
        #expect(model.collectionFilter == "Work")
        model.togglePinOfSelected()
        #expect(document.value.last?.isPinned == true)
        #expect(model.sections.first?.title == "Pinned")

        model.startCreating()
        model.form?.draft.name = "Unfinished"
        controller.close()
        let external = Snippet(name: "External", collection: "Other", text: "Reloaded", createdAt: .now)
        document.value.append(external)
        #expect(controller.resume())
        #expect(controller.panel?.contentView === hosting)
        #expect(model.collections == ["Other", "Work"])
        #expect(model.form?.draft.name == "Unfinished")
        #expect(model.form?.isNew == true)
        model.form = nil
        model.query = "External"
        model.collectionFilter = nil
        #expect(model.selectedSnippet?.id == external.id)
        model.deleteSelected()
        #expect(!document.value.contains { $0.id == external.id })
        #expect(document.value.count == entries.count)
        #expect(model.selectedSnippet == nil)
    }
}
