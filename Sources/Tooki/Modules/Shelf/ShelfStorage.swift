import Foundation

/// Tooki's own files for the shelf: copies of dropped files, and saved text, links and images.
/// They live in Application Support, so they survive restarts and reboots along with the shelf.
/// Each one gets its own folder so names never clash.
enum ShelfStorage {
    static let directory = StoragePaths.dataDirectory.appending(path: "shelf-items")

    static func newFolder() -> URL {
        directory.appending(path: UUID().uuidString)
    }

    /// Copies off the main thread; big folders can take a while. On APFS small copies are instant clones.
    static func copy(_ source: URL, to destination: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: source, to: destination)
                return true
            } catch {
                try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
                return false
            }
        }.value
    }

    /// Deletes the folder holding one of Tooki's files. Paths outside the storage folder are never touched.
    static func deleteFolder(of file: URL) {
        let folder = file.deletingLastPathComponent().standardizedFileURL
        guard folder.deletingLastPathComponent().path == directory.standardizedFileURL.path else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// Cleans up after a crash or quit: removes folders no shelf item refers to.
    static func deleteUnused(keeping files: [URL]) {
        let kept = Set(files.map { $0.deletingLastPathComponent().lastPathComponent })
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for folder in folders where !kept.contains(folder.lastPathComponent) {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
