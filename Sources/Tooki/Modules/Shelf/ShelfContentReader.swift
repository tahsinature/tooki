import AppKit

/// Reads a drop or a paste. Files come back as they are, for the shelf to link or copy;
/// text, links and images are saved as files in Tooki's storage.
@MainActor
enum ShelfContentReader {
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    static func savedItems(from pasteboard: NSPasteboard) -> [ShelfItem] {
        // Images dragged out of a browser also carry a link to the image; the picture is what's wanted.
        if let png = pngData(from: pasteboard) {
            return save(png, named: "Image.png", text: nil, isLink: false).map { [$0] } ?? []
        }
        let links = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? [])
            .filter { $0.scheme == "http" || $0.scheme == "https" }
        if !links.isEmpty {
            return links.compactMap { link in
                save(webloc(for: link), named: "\(link.host() ?? "Link").webloc", text: link.absoluteString, isLink: true)
            }
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return save(Data(text.utf8), named: "\(title(for: text)).txt", text: text, isLink: false).map { [$0] } ?? []
        }
        return []
    }

    private static func save(_ data: Data, named name: String, text: String?, isLink: Bool) -> ShelfItem? {
        let folder = ShelfStorage.newFolder()
        let file = folder.appending(path: name.replacing("/", with: "-"))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file)
            return ShelfItem(savedFile: file, text: text, isLink: isLink)
        } catch {
            return nil
        }
    }

    private static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        guard let tiff = pasteboard.data(forType: .tiff) else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    /// A `.webloc` file, which opens the link when double-clicked in Finder.
    private static func webloc(for link: URL) -> Data {
        let plist = ["URL": link.absoluteString]
        return (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
    }

    /// The first words of the text, keeping only letters and digits, like "onChange of shelf cursor".
    private static func title(for text: String) -> String {
        let maxLength = 30
        var title = ""
        for word in text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            guard title.count + word.count + 1 <= maxLength else {
                if title.isEmpty { title = String(word.prefix(maxLength)) }
                break
            }
            title += title.isEmpty ? String(word) : " " + word
        }
        return title.isEmpty ? "Text" : title
    }
}
