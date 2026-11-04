import Foundation

/// A copied image, stored as a PNG file named after its content.
public struct ClipboardImage: Codable, Equatable, Sendable {
    public var fileName: String
    public var width: Int
    public var height: Int
    /// Text found in the image. `nil` until text recognition has finished.
    public var recognizedText: String?

    public init(fileName: String, width: Int, height: Int, recognizedText: String? = nil) {
        self.fileName = fileName
        self.width = width
        self.height = height
        self.recognizedText = recognizedText
    }
}

public struct ClipboardItem: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    /// Empty for images. For files, their names.
    public var text: String
    public var image: ClipboardImage?
    /// Paths of copied files, e.g. from Finder.
    public var files: [String]?
    public var copiedAt: Date
    public var firstCopiedAt: Date
    public var timesCopied = 1
    public var isPinned = false
    public var sourceApp: String?

    public init(
        text: String = "",
        image: ClipboardImage? = nil,
        files: [String]? = nil,
        copiedAt: Date = Date(),
        sourceApp: String? = nil
    ) {
        self.text = text
        self.image = image
        self.files = files
        self.copiedAt = copiedAt
        self.firstCopiedAt = copiedAt
        self.sourceApp = sourceApp
    }

    /// History saved by older versions has no pin, count or first-copied date.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        image = try container.decodeIfPresent(ClipboardImage.self, forKey: .image)
        files = try container.decodeIfPresent([String].self, forKey: .files)
        copiedAt = try container.decode(Date.self, forKey: .copiedAt)
        firstCopiedAt = try container.decodeIfPresent(Date.self, forKey: .firstCopiedAt) ?? copiedAt
        timesCopied = try container.decodeIfPresent(Int.self, forKey: .timesCopied) ?? 1
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
    }

    public var title: String {
        if let image { return "Image (\(image.width)×\(image.height))" }
        if let files, files.count > 1 { return "\(files.count) files" }
        return text.replacingOccurrences(of: "\n", with: " ")
    }

    /// Two items with the same key are the same content copied twice.
    var duplicateKey: String {
        if let image { return "image:\(image.fileName)" }
        if let files { return "files:\(files.joined(separator: "\n"))" }
        return "text:\(text)"
    }
}

/// Newest-first list of copied text and images without duplicates.
public struct ClipboardLog: Codable, Equatable, Sendable {
    public private(set) var items: [ClipboardItem] = []

    public init(items: [ClipboardItem] = []) {
        self.items = items
    }

    /// File names of all images still in the history.
    public var imageFileNames: Set<String> {
        Set(items.compactMap { $0.image?.fileName })
    }

    /// Copying something again moves it to the top and keeps its pin, count and first-copied date.
    public mutating func record(_ item: ClipboardItem, maxItems: Int, maxImages: Int) {
        var item = item
        if let index = items.firstIndex(where: { $0.duplicateKey == item.duplicateKey }) {
            let previous = items.remove(at: index)
            item.id = previous.id
            item.isPinned = previous.isPinned
            item.timesCopied = previous.timesCopied + 1
            item.firstCopiedAt = previous.firstCopiedAt
        }
        items.insert(item, at: 0)
        trim(maxItems: maxItems, maxImages: maxImages)
    }

    /// Drops the oldest items beyond `maxItems`, and the oldest images beyond `maxImages`.
    /// Pinned items are always kept and do not count toward either limit.
    public mutating func trim(maxItems: Int, maxImages: Int) {
        var imageCount = 0
        var unpinnedCount = 0
        var kept: [ClipboardItem] = []
        for item in items {
            if item.isPinned {
                kept.append(item)
                continue
            }
            guard unpinnedCount < maxItems else { continue }
            if item.image != nil {
                imageCount += 1
                if imageCount > maxImages { continue }
            }
            unpinnedCount += 1
            kept.append(item)
        }
        items = kept
    }

    public mutating func setRecognizedText(_ text: String, forImage fileName: String) {
        for index in items.indices where items[index].image?.fileName == fileName {
            items[index].image?.recognizedText = text
        }
    }

    public mutating func togglePin(id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }

    public mutating func remove(id: ClipboardItem.ID) {
        items.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        items.removeAll()
    }
}
