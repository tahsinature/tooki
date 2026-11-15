import AppKit
import CoreGraphics
import ImageIO
import ShelfFeature
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

/// No configuration, history or monitoring is loaded. All files belong to this fixture.
@MainActor
final class VisualFixtures {
    let now = Date()
    let folder: URL
    let item: ShelfItem
    let shelf: Shelf
    let result: ShelfConversionResult

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "Landscape.png")
        let context = try #require(CGContext(data: nil, width: 160, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.15, green: 0.35, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 80))
        context.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 80, y: 0, width: 80, height: 80))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        item = ShelfItem(fileURL: url)
        shelf = Shelf(saved: SavedShelf(id: UUID(), name: "Design references", lastUsed: now, items: [item]))
        var options = ImageConversionOptions()
        options.preserveMetadata = false
        let preview = try ImageConversionPreview.create(source: url, options: options)
        result = try ShelfConversionResult(id: UUID(), item: item.conversionMetadata, preview: preview,
                                          details: preview.details(), revision: UUID())
    }

    func cleanUp() {
        result.preview.discard()
        try? FileManager.default.removeItem(at: folder)
    }

    func searchItems() -> [SearchItem] {
        [SearchItem(id: "clipboard", title: "Clipboard History", kind: "Command", group: .commands,
                    icon: .symbol("doc.on.clipboard"), actionTitle: "Run Command", run: {}),
         SearchItem(id: "notes", title: "Notes", kind: "Application", group: .applications,
                    icon: .symbol("note.text"), actionTitle: "Open Application", run: {}),
         SearchItem(id: "calendar", title: "Calendar", kind: "Application", group: .applications,
                    icon: .symbol("calendar"), actionTitle: "Open Application", run: {})]
    }

    func searchView(items: [SearchItem]? = nil) -> SearchView {
        let mode: SearchPanelController.Mode = items == nil ? .everything : .menuBar
        let model = SearchModel(items: items ?? searchItems(), placeholder: mode.placeholder,
                                title: mode.title, icon: mode.icon, filterGroups: mode.filterGroups,
                                history: LaunchHistory())
        return SearchView(model: model, onRun: { _, _ in }, onCancel: {}, onOpenSettings: {})
    }

    func snippets(form: Bool = false) -> SnippetPanelModel {
        let items = [Snippet(name: "Email signature", keyword: ";signature", collection: "Work", text: "Best regards,\nAlex", isPinned: true),
                     Snippet(name: "Meeting notes", keyword: ";meeting", collection: "Work", text: "Agenda\n• Updates\n• Next steps")]
        let document = JSONDocument(fileURL: folder.appending(path: "snippets.json"), initialValue: items)
        let model = SnippetPanelModel(snippets: document, usage: SnippetUsage(initialHistory: LaunchHistory()), targetAppName: "Notes")
        if form {
            model.startCreating()
            model.form?.draft.name = "Follow-up email"
            model.form?.draft.keyword = ";followup"
            model.form?.draft.collection = "Work"
            model.form?.draft.text = "Hi {name},\n\nThanks for meeting today.\n\n{cursor}"
        }
        return model
    }

    func conversion(phase: ShelfImageConversionFeature.Phase) -> ShelfImageConversionModel {
        var state = ShelfImageConversionFeature.State(items: [item.conversionMetadata])
        state.phase = phase
        if phase == .review || phase == .saving { state.results = [result] }
        return ShelfImageConversionModel(items: [item], shelf: shelf, initialState: state)
    }
}
