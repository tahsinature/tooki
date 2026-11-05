import AppKit
import TookiKit

/// One entry in the ⌘K actions menu.
struct ClipboardAction: Identifiable {
    enum Kind: Hashable {
        case paste, copy, openWith, togglePin, delete
        case open(appURL: URL)
    }

    enum Icon {
        case symbol(String)
        case app(NSImage)
    }

    let kind: Kind
    let title: String
    let icon: Icon
    let shortcut: String

    var id: Kind { kind }
    var isDestructive: Bool { kind == .delete }

    @MainActor
    static func all(for item: ClipboardItem, targetAppName: String?) -> [ClipboardAction] {
        var actions: [ClipboardAction] = []
        if item.canBeUsed {
            actions += [
                ClipboardAction(kind: .copy, title: "Copy to Clipboard", icon: .symbol("doc.on.doc"), shortcut: "↵"),
                ClipboardAction(kind: .paste, title: "Paste to \(targetAppName ?? "Active App")", icon: .symbol("arrow.up.forward.app"), shortcut: "⌘↵"),
            ]
        }
        if item.canBeUsed, ClipboardOpenWith.canOpen(item) {
            actions.append(ClipboardAction(kind: .openWith, title: "Open With…", icon: .symbol("arrow.up.forward.app"), shortcut: "⌘O"))
        }
        actions += [
            ClipboardAction(kind: .togglePin, title: item.isPinned ? "Unpin" : "Pin", icon: .symbol(item.isPinned ? "pin.slash" : "pin"), shortcut: "⌘P"),
            ClipboardAction(kind: .delete, title: "Delete", icon: .symbol("trash"), shortcut: "⌃X"),
        ]
        return actions
    }
}

extension ClipboardItem {
    /// `false` when copied files were moved or deleted, so pasting, dragging or opening would fail.
    var canBeUsed: Bool { missingFiles.isEmpty }
}
