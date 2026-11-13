import Foundation

public enum ConversionPreviewStorage {
    public static let directory = FileManager.default.temporaryDirectory
        .appending(path: "Tooki/conversion-previews", directoryHint: .isDirectory)

    static func newFolder() -> URL { directory.appending(path: UUID().uuidString, directoryHint: .isDirectory) }

    /// Files opened in external apps survive Discard/save for seven days. Never prune a
    /// newer directory, because an editor may still have its document open.
    public static func pruneExpired() {
        let files = FileManager.default
        let folders = (try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let expiry = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        for folder in folders {
            if let created = try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate, created < expiry {
                try? files.removeItem(at: folder)
            }
        }
    }
}
