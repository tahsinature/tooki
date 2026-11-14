import Foundation
import Testing
import TookiKit
@testable import Tooki

@MainActor
struct PanelGroupingTests {
    @Test func changingGroupingKeepsPinsOrderAndSelection() {
        let now = Date()
        let pinned = Snippet(name: "Pinned", text: "pin", isPinned: true)
        let recent = Snippet(name: "Recent", text: "recent", createdAt: now)
        let older = Snippet(name: "Older", text: "older", createdAt: now.addingTimeInterval(-30 * 86400))
        let document = JSONDocument(
            fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
            initialValue: [older, pinned, recent]
        )
        let config = JSONDocument(
            fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
            initialValue: TookiConfig()
        )
        let model = SnippetPanelModel(
            snippets: document, usage: SnippetUsage(), targetAppName: nil,
            groupByDate: { config.value.snippets.groupByDate }
        )
        model.selectedID = older.id
        let groupedOrder = model.sections.flatMap(\.items).map(\.id)
        #expect(model.sections.count == 3)

        config.value.snippets.groupByDate = false
        #expect(model.sections.count == 2)
        #expect(model.sections.first?.title == "Pinned")
        #expect(model.sections.last?.title == nil)
        #expect(model.sections.flatMap(\.items).map(\.id) == groupedOrder)
        #expect(model.selectedSnippet?.id == older.id)
        model.moveSelection(by: -1)
        #expect(model.selectedSnippet?.id == recent.id)

        config.value.snippets.groupByDate = true
        #expect(model.sections.count == 3)
        #expect(model.selectedSnippet?.id == recent.id)
    }
}
