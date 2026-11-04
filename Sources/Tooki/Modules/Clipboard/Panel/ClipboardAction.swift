import TookiKit

/// One entry in the ⌘K actions menu.
struct ClipboardAction: Identifiable {
    enum Kind {
        case paste, copy, togglePin, delete
    }

    let kind: Kind
    let title: String
    let icon: String
    let shortcut: String

    var id: Kind { kind }
    var isDestructive: Bool { kind == .delete }

    static func all(for item: ClipboardItem, targetAppName: String?) -> [ClipboardAction] {
        [
            ClipboardAction(kind: .paste, title: "Paste to \(targetAppName ?? "Active App")", icon: "doc.on.clipboard", shortcut: "↵"),
            ClipboardAction(kind: .copy, title: "Copy to Clipboard", icon: "doc.on.doc", shortcut: "⌘↵"),
            ClipboardAction(kind: .togglePin, title: item.isPinned ? "Unpin" : "Pin", icon: item.isPinned ? "pin.slash" : "pin", shortcut: "⌘P"),
            ClipboardAction(kind: .delete, title: "Delete", icon: "trash", shortcut: "⌃X"),
        ]
    }
}
