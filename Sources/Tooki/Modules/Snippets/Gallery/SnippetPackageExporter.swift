import AppKit
import Observation
import SwiftUI
import TookiKit
import UniformTypeIdentifiers

@MainActor
enum SnippetPackageExporter {
    static let contentType = UTType(exportedAs: "us.tahsin.tooki.snippet", conformingTo: .json)

    static func export(_ snippet: Snippet) {
        let options = ShareOptions(snippet: snippet)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = snippet.name + ".tookisnippet"
        panel.title = "Share Snippet"
        panel.message = "Personal setup, pin state and usage are excluded. Review your logic before sharing."
        let accessory = NSHostingView(rootView: ShareOptionsView(options: options))
        accessory.frame = NSRect(x: 0, y: 0, width: 440, height: 150)
        panel.accessoryView = accessory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var package = SnippetPackage(exporting: snippet, author: options.author, description: options.summary)
            package.identity.version = options.version
            package.identity.author = options.author
            try package.validate()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(package).write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}

@MainActor @Observable
private final class ShareOptions {
    var author: String
    var version: String
    var summary = ""
    init(snippet: Snippet) {
        author = snippet.package?.author ?? ""
        version = snippet.package?.version ?? "1.0.0"
    }
}

private struct ShareOptionsView: View {
    @Bindable var options: ShareOptions
    var body: some View {
        Form {
            TextField("Author", text: $options.author)
            TextField("Version", text: $options.version)
            TextField("Description", text: $options.summary)
        }.padding(12)
    }
}
