import Foundation

/// Where "Add to Shelf" puts things: an existing shelf or a new one.
enum ShelfDestination: Hashable {
    case existing(Shelf.ID)
    case new
}

/// The "Add to Shelf" choices any panel can show in its ⌘K menu. Each panel wraps them in its
/// own action type, the same way Open With does.
@MainActor
enum ShelfDestinationChoices {
    struct Choice {
        let destination: ShelfDestination
        let title: String
        let icon: PanelIcon
        /// Shown where a shortcut would be, e.g. "3 items".
        let detail: String
    }

    /// Every shelf, most recently used first, then a new one.
    static func all(in library: ShelfLibrary) -> [Choice] {
        let shelves = library.shelves.sorted { $0.lastUsed > $1.lastUsed }.map { shelf in
            Choice(
                destination: .existing(shelf.id),
                title: shelf.name,
                icon: .symbol("tray.full"),
                detail: shelf.items.count == 1 ? "1 item" : "\(shelf.items.count) items"
            )
        }
        return shelves + [Choice(destination: .new, title: "New Shelf", icon: .symbol("plus"), detail: "")]
    }

    /// For files, which can go on as a link to the original or as Tooki's own copy.
    static let modes: [(mode: ShelfAddMode, title: String, icon: PanelIcon)] = [
        (.copy, "Add a Copy", .symbol("doc.on.doc")),
        (.original, "Add the Original", .symbol("link")),
    ]
}
