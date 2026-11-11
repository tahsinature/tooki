import AppKit

/// One entry in the shelf manager's ⌘K menu, for a shelf or for an item on it.
struct ShelfManagerAction: PanelActionItem {
    enum Kind: Hashable {
        // A shelf
        case openShelf, showShelf, renameShelf, closeShelf, confirmClose, cancelClose, pasteFromClipboard
        case paste(ShelfAddMode)
        // An item
        case open, openWith, quickLook, showInFinder, copyFile, copyPath, rename, remove
        case openIn(appURL: URL)
        // Every shelf window, or only the open shelf when inside one
        case toggleShelves, newShelf
    }

    let kind: Kind
    let title: String
    let icon: PanelIcon
    var shortcut = ""

    var id: Kind { kind }
    var isDestructive: Bool { [.closeShelf, .confirmClose, .remove].contains(kind) }

    static let toggleShelves = ShelfManagerAction(
        kind: .toggleShelves, title: "Show or Hide All Shelves", icon: .symbol("tray.full"), shortcut: "⌘S"
    )

    static let newShelf = ShelfManagerAction(
        kind: .newShelf, title: "New Shelf", icon: .symbol("plus.rectangle.on.rectangle"), shortcut: "⌘N"
    )

    static let forShelf = [
        ShelfManagerAction(kind: .openShelf, title: "Open Shelf", icon: .symbol("arrow.right.circle"), shortcut: "↵"),
        ShelfManagerAction(kind: .showShelf, title: "Show on Screen", icon: .symbol("macwindow"), shortcut: "⌘↵"),
        ShelfManagerAction(kind: .renameShelf, title: "Rename Shelf", icon: .symbol("pencil"), shortcut: "⌘R"),
        ShelfManagerAction(kind: .pasteFromClipboard, title: "Paste from Clipboard", icon: .symbol("doc.on.clipboard")),
        newShelf,
        toggleShelves,
        ShelfManagerAction(kind: .closeShelf, title: "Close Shelf", icon: .symbol("xmark.circle"), shortcut: "⌃X"),
    ]

    static let closeConfirmation = [
        ShelfManagerAction(kind: .confirmClose, title: "Close Shelf and Delete Copies", icon: .symbol("trash"), shortcut: "↵"),
        ShelfManagerAction(kind: .cancelClose, title: "Cancel", icon: .symbol("xmark"), shortcut: "esc"),
    ]

    @MainActor
    static func forItem(in shelf: Shelf) -> [ShelfManagerAction] {
        itemActions.map {
            $0.kind == .toggleShelves
                ? ShelfManagerAction(kind: .toggleShelves, title: "Show or Hide “\(shelf.name)”", icon: .symbol("macwindow"), shortcut: "⌘S")
                : $0
        }
    }

    private static let itemActions = [
        ShelfManagerAction(kind: .open, title: "Open", icon: .symbol("arrow.up.forward.app"), shortcut: "↵"),
        ShelfManagerAction(kind: .openWith, title: "Open With…", icon: .symbol("arrow.up.right.square"), shortcut: "⌘O"),
        ShelfManagerAction(kind: .quickLook, title: "Quick Look", icon: .symbol("eye"), shortcut: "⌘Y"),
        ShelfManagerAction(kind: .showInFinder, title: "Show in Finder", icon: .symbol("folder"), shortcut: "⇧⌘F"),
        ShelfManagerAction(kind: .copyFile, title: "Copy File", icon: .symbol("doc.on.doc"), shortcut: "⌘C"),
        ShelfManagerAction(kind: .copyPath, title: "Copy Path", icon: .symbol("link"), shortcut: "⇧⌘C"),
        ShelfManagerAction(kind: .rename, title: "Rename…", icon: .symbol("pencil"), shortcut: "⌘R"),
        toggleShelves,
        ShelfManagerAction(kind: .remove, title: "Remove from Shelf", icon: .symbol("trash"), shortcut: "⌃X"),
    ]

    /// Pasted files can go on as Tooki's own copy or as a link to the original.
    @MainActor static let pasteModes = ShelfDestinationChoices.modes.map {
        ShelfManagerAction(kind: .paste($0.mode), title: $0.title, icon: $0.icon)
    }

    @MainActor
    static func openWith(_ item: ShelfItem) -> [ShelfManagerAction] {
        OpenWithApps.apps(toOpen: item.url).map { app in
            ShelfManagerAction(kind: .openIn(appURL: app.url), title: app.name, icon: .image(app.icon), shortcut: app.isDefault ? "Default" : "")
        }
    }
}
