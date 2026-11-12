import AppKit
import TookiKit

/// Finds and launches apps that can open a clipboard item: an image, files or a link.
@MainActor
enum ClipboardOpenWith {
    static func canOpen(_ item: ClipboardItem) -> Bool {
        !urls(for: item).isEmpty
    }

    /// One action per app that can open the item. The default app comes first, then the rest by name.
    static func actions(for item: ClipboardItem) -> [ClipboardAction] {
        guard let first = urls(for: item).first else { return [] }
        return OpenWithApps.apps(toOpen: first).map { app in
            ClipboardAction(kind: .open(appURL: app.url), title: app.name, icon: .image(app.icon), detail: app.isDefault ? "Default" : nil)
        }
    }

    static func open(_ item: ClipboardItem, with appURL: URL) {
        let urls = item.image.map { [temporaryCopy(of: $0)] } ?? urls(for: item)
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func urls(for item: ClipboardItem) -> [URL] {
        if let image = item.image { return [ClipboardImageStore.url(for: image)] }
        if let files = item.files { return files.map { URL(fileURLWithPath: $0) } }
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.contentType == .link, let url = URL(string: text) { return [url] }
        return []
    }

    /// A copy with a readable name. Editing the image in another app must not change the copy saved in the history.
    static func temporaryCopy(of image: ClipboardImage) -> URL {
        let original = ClipboardImageStore.url(for: image)
        let directory = FileManager.default.temporaryDirectory.appending(path: "Tooki")
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        let copy = directory.appending(path: "Clipboard Image \(stamp.replacing(":", with: ".")).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: original, to: copy)
            return copy
        } catch {
            return original
        }
    }
}
