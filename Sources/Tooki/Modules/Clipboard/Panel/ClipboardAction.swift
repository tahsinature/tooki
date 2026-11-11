import AppKit
import TookiKit

/// One entry in the ⌘K actions menu.
struct ClipboardAction: PanelActionItem {
    enum Kind: Hashable {
        case paste, copy, openWith, togglePin, delete
        case open(appURL: URL)
        /// Opens the list of shelves.
        case addToShelf
        /// A shelf was picked. Files then ask whether to add copies or the originals.
        case addTo(ShelfDestination)
        case add(to: ShelfDestination, mode: ShelfAddMode)
    }

    let kind: Kind
    let title: String
    let icon: PanelIcon
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
        if item.canBeUsed {
            actions.append(ClipboardAction(kind: .addToShelf, title: "Add to Shelf…", icon: .symbol("tray.and.arrow.down"), shortcut: "⌘S"))
        }
        actions += [
            ClipboardAction(kind: .togglePin, title: item.isPinned ? "Unpin" : "Pin", icon: .symbol(item.isPinned ? "pin.slash" : "pin"), shortcut: "⇧⌘P"),
            ClipboardAction(kind: .delete, title: "Delete", icon: .symbol("trash"), shortcut: "⌃X"),
        ]
        return actions
    }
}

extension ClipboardAction {
    @MainActor
    static func shelves(in library: ShelfLibrary) -> [ClipboardAction] {
        ShelfDestinationChoices.all(in: library).map {
            ClipboardAction(kind: .addTo($0.destination), title: $0.title, icon: $0.icon, shortcut: $0.detail)
        }
    }

    @MainActor
    static func modes(for destination: ShelfDestination) -> [ClipboardAction] {
        ShelfDestinationChoices.modes.map {
            ClipboardAction(kind: .add(to: destination, mode: $0.mode), title: $0.title, icon: $0.icon, shortcut: "")
        }
    }
}

extension ClipboardItem {
    /// `false` when copied files were moved or deleted, so pasting, dragging or opening would fail.
    var canBeUsed: Bool { missingFiles.isEmpty }
}
