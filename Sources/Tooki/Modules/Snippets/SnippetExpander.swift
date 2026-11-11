import CoreGraphics
import Foundation
import TookiKit

/// Watches typing and replaces a snippet keyword (e.g. `;date`) or an emoji code (`:rocket:`) as soon as it is typed.
@MainActor
final class SnippetExpander: KeyEventHandler {
    var isEnabled = true

    private let snippets: JSONDocument<[Snippet]>
    private let inserter: SnippetInserter
    private let usage: SnippetUsage
    private var buffer = TypedBuffer()

    init(snippets: JSONDocument<[Snippet]>, inserter: SnippetInserter, usage: SnippetUsage) {
        self.snippets = snippets
        self.inserter = inserter
        self.usage = usage
    }

    func handle(_ event: CGEvent, type: CGEventType) -> Bool {
        guard isEnabled else { return false }
        switch type {
        case .leftMouseDown, .rightMouseDown:
            buffer.reset()
            return false
        case .keyDown:
            return handleKeyDown(event)
        default:
            return false
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
            buffer.reset()
            return false
        }
        if event.getIntegerValueField(.keyboardEventKeycode) == Int64(KeyCode.delete) {
            buffer.deleteLast()
            return false
        }
        let characters = typedCharacters(of: event)
        guard !characters.isEmpty, characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            buffer.reset()
            return false
        }

        buffer.append(characters)
        if let snippet = KeywordMatcher.match(typed: buffer.text, in: snippets.value) {
            buffer.reset()
            // The last keyword character is swallowed, so only the earlier ones need deleting.
            inserter.insert(snippet, deletingTypedCharacters: snippet.keyword.count - 1)
            usage.record(snippet.id)
            return true
        }
        if let match = EmojiCatalog.shortcodeMatch(typed: buffer.text) {
            buffer.reset()
            let snippet = Snippet(name: match.emoji.name, text: match.emoji.character)
            inserter.insert(snippet, deletingTypedCharacters: match.length - 1)
            return true
        }
        return false
    }

    private func typedCharacters(of event: CGEvent) -> String {
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &characters)
        return String(utf16CodeUnits: characters, count: length)
    }
}
