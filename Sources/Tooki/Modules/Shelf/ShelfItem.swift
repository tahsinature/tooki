import AppKit
import Foundation

/// One thing on the shelf. Everything on the shelf is a file: dropped text, links and images
/// are saved as files first so they can be dragged into Finder like any other file.
///
/// An item is either a link to your original file, or a copy Tooki keeps in its own storage.
/// Dragging an original out can move it; dragging a copy out never touches the original.
struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    /// Invalidates previews after replacing a file at the same path. Optional for older saved shelves.
    var conversionRevision: UUID?
    private(set) var path: String
    /// Dropped text or a link. Dragging the item out offers this as well as the saved file.
    var text: String?
    var isLink = false
    /// Tooki created the file (a copy, or dropped text, links and images) and deletes it once it's off the shelf.
    var ownsFile = false
    /// For copies of dropped files: where the original is.
    var originalPath: String?
    /// Read from disk each time, because some apps (like Firefox) drop an empty file and fill it
    /// in a moment later. `nil` for folders, whose size would take too long to add up.
    var byteSize: Int64? {
        let file = exists ? url : originalPath.map(URL.init(fileURLWithPath:)) ?? url
        let values = try? file.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        return values?.isDirectory == true ? nil : Int64(values?.fileSize ?? 0)
    }

    var url: URL { URL(fileURLWithPath: path) }
    var isCopy: Bool { ownsFile }
    /// Originals are the same item when the path matches; copies when the original matches.
    var dedupeKey: String { originalPath.map { "copy:" + $0 } ?? path }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
    var name: String { isLink ? (text ?? url.lastPathComponent) : url.lastPathComponent }

    var detail: String {
        if isLink { return "Link" }
        guard let byteSize else { return folderDetail }
        let size = byteSize.formatted(.byteCount(style: .file))
        return text == nil ? size : "Text · \(size)"
    }

    /// The short label at the end of a row: the size, or what it is when it has none.
    var shortDetail: String {
        if isLink { return "Link" }
        return byteSize?.formatted(.byteCount(style: .file)) ?? "Folder"
    }

    /// Counts only the top level, like Finder, so it stays instant for big folders.
    private var folderDetail: String {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )
        guard let count = contents?.count else { return "Folder" }
        return "Folder · \(count) \(count == 1 ? "item" : "items")"
    }

    /// The folder the original is in, like `~/Downloads`. Saved text, links and images have none.
    var location: String? {
        guard let sourcePath = ownsFile ? originalPath : path else { return nil }
        return Self.abbreviated(URL(fileURLWithPath: sourcePath).deletingLastPathComponent().path)
    }

    /// What the Original or Copy badge means, shown when hovering over it.
    var tooltip: String {
        if originalPath != nil { return "Copy: Tooki's own file. The original never moves." }
        if isLink { return "Saved link" }
        if ownsFile { return "Copy: saved by Tooki from a drop or paste" }
        return "Original: dragging it out uses the real file"
    }

    /// What kind of item this is, for its details.
    var mode: String {
        if originalPath != nil { return "Copy. The original never moves." }
        if ownsFile { return "Saved by Tooki from a drop or paste" }
        return "Link to the original. Dragging it out can move it."
    }

    /// Where the file is now, like `~/Downloads/a.pdf`.
    var displayPath: String { Self.abbreviated(path) }
    /// Where it came from: the original for a copy, the file itself for an original.
    var displayOriginalPath: String? {
        if let originalPath { return Self.abbreviated(originalPath) }
        return ownsFile ? nil : displayPath
    }

    private static func abbreviated(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    /// After the file was renamed.
    mutating func relocate(to url: URL) {
        path = url.path
    }

    init(fileURL: URL) {
        path = fileURL.path
    }

    /// A copy of `original` that will live at `copyURL` once copying finishes.
    init(copyOf original: URL, at copyURL: URL) {
        self.init(fileURL: original)
        path = copyURL.path
        originalPath = original.path
        ownsFile = true
    }

    init(savedFile: URL, text: String?, isLink: Bool) {
        self.init(fileURL: savedFile)
        self.text = text
        self.isLink = isLink
        ownsFile = true
    }
}
