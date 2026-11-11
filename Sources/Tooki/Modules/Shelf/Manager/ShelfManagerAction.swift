import AppKit

/// One entry in the shelf manager's ⌘K menu, for a shelf or for an item on it.
struct ShelfManagerAction: PanelActionItem {
    enum Kind: Hashable {
        // A shelf
        case openShelf, showShelf, closeShelf, confirmClose, cancelClose
        // An item
        case open, openWith, quickLook, showInFinder, copyFile, copyPath, rename, remove
        case openIn(appURL: URL)
    }

    let kind: Kind
    let title: String
    let icon: PanelIcon
    var shortcut = ""

    var id: Kind { kind }
    var isDestructive: Bool { [.closeShelf, .confirmClose, .remove].contains(kind) }

    static let forShelf = [
        ShelfManagerAction(kind: .openShelf, title: "Open Shelf", icon: .symbol("arrow.right.circle"), shortcut: "↵"),
        ShelfManagerAction(kind: .showShelf, title: "Show on Screen", icon: .symbol("macwindow"), shortcut: "⌘↵"),
        ShelfManagerAction(kind: .closeShelf, title: "Close Shelf", icon: .symbol("xmark.circle"), shortcut: "⌃X"),
    ]

    static let closeConfirmation = [
        ShelfManagerAction(kind: .confirmClose, title: "Close Shelf and Delete Copies", icon: .symbol("trash"), shortcut: "↵"),
        ShelfManagerAction(kind: .cancelClose, title: "Cancel", icon: .symbol("xmark"), shortcut: "esc"),
    ]

    static let forItem = [
        ShelfManagerAction(kind: .open, title: "Open", icon: .symbol("arrow.up.forward.app"), shortcut: "↵"),
        ShelfManagerAction(kind: .openWith, title: "Open With…", icon: .symbol("arrow.up.right.square"), shortcut: "⌘O"),
        ShelfManagerAction(kind: .quickLook, title: "Quick Look", icon: .symbol("eye"), shortcut: "⌘Y"),
        ShelfManagerAction(kind: .showInFinder, title: "Show in Finder", icon: .symbol("folder"), shortcut: "⇧⌘F"),
        ShelfManagerAction(kind: .copyFile, title: "Copy File", icon: .symbol("doc.on.doc"), shortcut: "⌘C"),
        ShelfManagerAction(kind: .copyPath, title: "Copy Path", icon: .symbol("link"), shortcut: "⇧⌘C"),
        ShelfManagerAction(kind: .rename, title: "Rename…", icon: .symbol("pencil"), shortcut: "⌘R"),
        ShelfManagerAction(kind: .remove, title: "Remove from Shelf", icon: .symbol("trash"), shortcut: "⌃X"),
    ]

    @MainActor
    static func openWith(_ item: ShelfItem) -> [ShelfManagerAction] {
        OpenWithApps.apps(toOpen: item.url).map { app in
            ShelfManagerAction(kind: .openIn(appURL: app.url), title: app.name, icon: .image(app.icon), shortcut: app.isDefault ? "Default" : "")
        }
    }
}
