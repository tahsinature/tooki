import ComposableArchitecture
import CoreGraphics
import Foundation
import ImageIO
import ShelfFeature
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func conversionReducerUsesNativeCommitAndUpdatesTheExactShelfRow() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try conversionImage(in: folder)
        let item = ShelfItem(fileURL: source)
        let shelf = Shelf(saved: SavedShelf(id: UUID(), name: "Fixture", lastUsed: .now, items: [item]))
        var closed = false
        var saved: [UUID] = []
        let model = ShelfImageConversionModel(items: [item], shelf: shelf, onClose: { closed = true })
        model.onSaved = { saved = $0 }
        var client = model.makeClient()
        // Exercise real conversion and commit only in this fixture. Never prune the user's previews.
        client.validate = { _ in }
        let store = TestStore(initialState: ShelfImageConversionFeature.State(items: [item.conversionMetadata])) {
            ShelfImageConversionFeature()
        } withDependencies: {
            $0.shelfConversionClient = client
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.convert)
        await store.receive(\.preparationFinished)
        let preview = try #require(store.state.current?.preview)
        defer { preview.discard() }
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(shelf.items.first?.url == source)
        await store.send(.save(.replace))
        await store.receive(\.saveFinished)
        await store.finish()
        #expect(closed)
        #expect(saved == [item.id])
        #expect(shelf.items.first?.id == item.id)
        #expect(shelf.items.first?.url.pathExtension == "jpg")
        #expect(shelf.selection == [item.id])
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(!FileManager.default.fileExists(atPath: preview.url.path))
    }

    @Test func nativeConversionRejectsRemovedItemWithoutCreatingAnOrphanedOutput() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try conversionImage(in: folder)
        let item = ShelfItem(fileURL: source)
        let shelf = Shelf(saved: SavedShelf(id: UUID(), name: "Fixture", lastUsed: .now, items: [item]))
        let model = ShelfImageConversionModel(items: [item], shelf: shelf)
        let client = model.makeClient()
        let preview = try await client.prepare(item.conversionMetadata, ImageConversionOptions())
        defer { preview.discard() }
        let details = try await client.details(preview)
        let result = ShelfConversionResult(id: UUID(), item: item.conversionMetadata, preview: preview,
                                           details: details, revision: UUID())
        shelf.remove([item.id])
        await #expect(throws: ImageConversionError.self) { try await client.save(result, .replace) }
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(!FileManager.default.fileExists(atPath: source.deletingPathExtension().appendingPathExtension("jpg").path))
        let remaining = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        #expect(remaining.map { $0.resolvingSymlinksInPath() } == [source.resolvingSymlinksInPath()])
    }

    private func conversionImage(in folder: URL) throws -> URL {
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let url = folder.appending(path: "fixture.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
