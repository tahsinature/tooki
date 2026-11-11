import Foundation
import Observation

/// Every shelf, saved in Application Support so they come back after Tooki restarts.
@MainActor
@Observable
final class ShelfLibrary {
    /// In the order they were made.
    private(set) var shelves: [Shelf] = []

    static let fileURL = StoragePaths.dataDirectory.appending(path: "shelves.json")
    /// Where the single shelf was saved before Tooki had more than one.
    private static let oldFileURL = StoragePaths.dataDirectory.appending(path: "shelf.json")

    var isEmpty: Bool { shelves.isEmpty }
    var itemCount: Int { shelves.map(\.items.count).reduce(0, +) }
    var mostRecent: Shelf? { shelves.max { $0.lastUsed < $1.lastUsed } }

    /// Empty shelves aren't brought back.
    func load() {
        shelves = Self.readSaved().map(Shelf.init(saved:)).filter { !$0.isEmpty }
        shelves.forEach(watch)
        let ownedFiles = shelves.flatMap(\.items).filter(\.ownsFile).map(\.url)
        ShelfStorage.deleteUnused(keeping: ownedFiles)
        save()
        try? FileManager.default.removeItem(at: Self.oldFileURL)
    }

    func newShelf(named name: String? = nil) -> Shelf {
        let shelf = Shelf(name: name ?? nextName())
        watch(shelf)
        shelves.append(shelf)
        save()
        return shelf
    }

    /// Takes the shelf away for good. Tooki's own copies on it are deleted.
    func remove(_ shelf: Shelf) {
        shelf.onEmptied = {}
        shelf.clear()
        shelves.removeAll { $0.id == shelf.id }
        save()
    }

    func dropMissingFiles() {
        shelves.forEach { $0.dropMissingFiles() }
    }

    /// Finds a shelf by its id or its name (any case).
    func shelf(matching reference: String) -> Shelf? {
        shelves.first { $0.id.uuidString.caseInsensitiveCompare(reference) == .orderedSame }
            ?? shelves.first { $0.name.caseInsensitiveCompare(reference) == .orderedSame }
    }

    /// What's saved on disk. Also read by the `tooki shelf list` command.
    static func readSaved() -> [SavedShelf] {
        if let data = JSONFile.read(fileURL) {
            return (try? JSONFile.decoder.decode([SavedShelf].self, from: data)) ?? []
        }
        guard let data = JSONFile.read(oldFileURL),
              let items = try? JSONFile.decoder.decode([ShelfItem].self, from: data)
        else { return [] }
        return [SavedShelf(id: UUID(), name: "Shelf 1", lastUsed: Date(), items: items)]
    }

    private func watch(_ shelf: Shelf) {
        shelf.onChange = { [weak self] in self?.save() }
    }

    private func save() {
        guard let data = try? JSONFile.encoder.encode(shelves.map(\.saved)) else { return }
        try? JSONFile.write(data, to: Self.fileURL)
    }

    /// "Shelf 1", "Shelf 2", …, reusing the lowest number that's free.
    private func nextName() -> String {
        let names = Set(shelves.map(\.name))
        let number = (1...).first { !names.contains("Shelf \($0)") } ?? 1
        return "Shelf \(number)"
    }
}

struct SavedShelf: Codable {
    var id: UUID
    var name: String
    var lastUsed: Date
    var items: [ShelfItem]
}
