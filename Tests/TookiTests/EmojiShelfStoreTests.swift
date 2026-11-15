import AppKit
import Foundation
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func emojiAdapterBoundsNavigationAndRetainsQueryOnReset() {
        let model = EmojiPanelModel(recentCharacters: [])
        model.query = "face"
        model.moveSelection(by: Int.max)
        #expect(model.selection == model.results.count - 1)
        model.moveActionSelection(by: Int.max)
        #expect(model.actionSelection == 2)
        model.resetPosition()
        #expect(model.selection == 0)
        #expect(model.query == "face")
    }

    @Test func shelfAdaptersReflectNativeItemsAndRenameWithoutDiskWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let urls = ["Report.pdf", "Photo.png"].map { directory.appending(path: $0) }
        for url in urls { try Data().write(to: url) }
        let items = urls.map(ShelfItem.init(fileURL:))
        let shelf = Shelf(saved: SavedShelf(id: UUID(), name: "Work", lastUsed: .now, items: items))
        shelf.moveSelection(by: 1, extending: false)
        shelf.moveSelection(by: Int.max, extending: true)
        #expect(shelf.selection == Set(items.map(\.id)))
        shelf.selectConverted(items.map(\.id))
        #expect(shelf.cursor == items.first?.id)
        #expect(shelf.selection.count == 2)

        // Seeded shelves have no persistence callback. This fixture never loads or saves user data.
        let library = ShelfLibrary(initialShelves: [shelf])
        let model = ShelfManagerModel(library: library)
        model.query = "report"
        #expect(model.shelves.map(\.id) == [shelf.id])
        model.open(shelf)
        model.moveSelection(by: Int.max)
        #expect(model.selectedItem?.id == items.last?.id)
        model.startRenaming(shelf)
        model.query = "Renamed"
        model.finishRenaming(save: true)
        #expect(shelf.name == "Renamed")
        #expect(model.store.shelves.first?.name == "Renamed")
        model.query = "missing"
        shelf.rename(to: "External")
        model.refresh()
        model.query = "external"
        model.closeOpenShelf()
        #expect(model.selectedShelf?.name == "External")
    }
}
