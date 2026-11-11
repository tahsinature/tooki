import AppKit
import TookiKit

/// One entry in the snippet panel's ⌘K menu.
struct SnippetAction: PanelActionItem {
    enum Kind: Hashable {
        case copy, paste, openWith, togglePin, edit, duplicate, create, delete
        case open(appURL: URL)
        case confirmDelete, cancelDelete
    }

    let kind: Kind
    let title: String
    let icon: PanelIcon
    var shortcut = ""

    var id: Kind { kind }
    var isDestructive: Bool { kind == .delete || kind == .confirmDelete }

    static func all(for snippet: Snippet, targetAppName: String?) -> [SnippetAction] {
        [
            SnippetAction(kind: .copy, title: "Copy to Clipboard", icon: .symbol("doc.on.doc"), shortcut: "↵"),
            SnippetAction(kind: .paste, title: "Paste to \(targetAppName ?? "Active App")", icon: .symbol("arrow.up.forward.app"), shortcut: "⌘↵"),
            SnippetAction(kind: .openWith, title: "Open With…", icon: .symbol("arrow.up.right.square"), shortcut: "⌘O"),
            SnippetAction(kind: .togglePin, title: snippet.isPinned ? "Unpin Snippet" : "Pin Snippet",
                          icon: .symbol(snippet.isPinned ? "pin.slash" : "pin"), shortcut: "⇧⌘P"),
            SnippetAction(kind: .edit, title: "Edit Snippet", icon: .symbol("pencil"), shortcut: "⌘E"),
            SnippetAction(kind: .duplicate, title: "Duplicate Snippet", icon: .symbol("plus.square.on.square"), shortcut: "⌘D"),
            SnippetAction(kind: .create, title: "Create Snippet", icon: .symbol("plus"), shortcut: "⌘N"),
            SnippetAction(kind: .delete, title: "Delete Snippet", icon: .symbol("trash"), shortcut: "⌃X"),
        ]
    }

    /// Shown in place of the main list before a snippet is deleted. Snippets are written by hand,
    /// so unlike clipboard entries they are not removed with a single key.
    static let deleteConfirmation = [
        SnippetAction(kind: .confirmDelete, title: "Delete Snippet", icon: .symbol("trash"), shortcut: "↵"),
        SnippetAction(kind: .cancelDelete, title: "Cancel", icon: .symbol("xmark"), shortcut: "esc"),
    ]
}
