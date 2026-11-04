import AppKit
import TookiKit

/// Fills in a snippet's placeholders (asking for arguments if needed) and pastes it.
@MainActor
final class SnippetInserter {
    private var argumentPanel: FloatingPanel?

    func insert(_ snippet: Snippet, deletingTypedCharacters count: Int = 0) {
        for _ in 0..<max(count, 0) { SyntheticEvent.press(KeyCode.delete) }

        let names = PlaceholderExpander.argumentNames(in: snippet.text)
        guard !names.isEmpty else {
            paste(snippet, arguments: [:])
            return
        }
        askForArguments(names, title: snippet.name) { [weak self] values in
            self?.paste(snippet, arguments: values)
        }
    }

    private func paste(_ snippet: Snippet, arguments: [String: String]) {
        let context = ExpansionContext(
            clipboard: NSPasteboard.general.string(forType: .string) ?? "",
            arguments: arguments
        )
        let result = PlaceholderExpander.expand(snippet.text, context: context)
        Task {
            // Give the target app a moment to process the deleted keyword or closed panel.
            try? await Task.sleep(for: .milliseconds(60))
            Paster.paste(result.text, cursorOffsetFromEnd: result.cursorOffsetFromEnd)
        }
    }

    private func askForArguments(_ names: [String], title: String, completion: @escaping ([String: String]) -> Void) {
        argumentPanel?.close()
        let height = CGFloat(120 + names.count * 56)
        let panel = FloatingPanel(size: CGSize(width: 420, height: height)) {
            ArgumentPromptView(title: title, names: names) { [weak self] values in
                self?.argumentPanel?.close()
                self?.argumentPanel = nil
                if let values { completion(values) }
            }
        }
        argumentPanel = panel
        panel.present()
    }
}
