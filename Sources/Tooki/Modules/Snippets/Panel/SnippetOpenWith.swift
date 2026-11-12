import AppKit
import TookiKit
import UniformTypeIdentifiers

/// Opens a snippet in another app: a link in a browser, anything else as a text file.
@MainActor
enum SnippetOpenWith {
    static func actions(for snippet: Snippet) -> [SnippetAction] {
        let apps = link(in: snippet).map(OpenWithApps.apps(toOpen:)) ?? OpenWithApps.apps(toOpen: .plainText)
        return apps.map { app in
            SnippetAction(kind: .open(appURL: app.url), title: app.name, icon: .image(app.icon), detail: app.isDefault ? "Default" : nil)
        }
    }

    static func open(_ snippet: Snippet, with appURL: URL) {
        let target = link(in: snippet) ?? textFile(for: snippet)
        NSWorkspace.shared.open([target], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// The snippet's text when it is nothing but a web link.
    private static func link(in snippet: Snippet) -> URL? {
        let text = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }
        return url
    }

    /// A temporary copy named after the snippet, so editing it never changes the snippet itself.
    private static func textFile(for snippet: Snippet) -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Tooki/Snippets")
        let name = snippet.name.replacing("/", with: "-").replacing(":", with: "-")
        let file = directory.appending(path: "\(name.isEmpty ? "Snippet" : name).txt")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? snippet.text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
