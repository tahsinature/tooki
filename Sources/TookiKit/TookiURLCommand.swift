import Foundation

/// A command sent to Tooki with a `tooki://` link, so scripts and other apps can drive it:
/// `open -g "tooki://shelf/add?path=/Users/me/report.pdf"`.
///
/// Any app or web page can open these links, so they only run harmless commands.
public enum TookiURLCommand: Equatable, Sendable {
    case shelf(ShelfCommand)
    case run(HotkeyAction)

    public init?(_ url: URL) {
        guard url.scheme?.lowercased() == "tooki",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let verb = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch components.host?.lowercased() {
        case "shelf":
            guard let command = ShelfCommand(verb: verb, query: components.queryItems ?? []) else { return nil }
            self = .shelf(command)
        case "run":
            // Only Tooki's own actions: a link must not be able to launch arbitrary apps.
            guard HotkeyAction.builtIns.contains(verb), let action = HotkeyAction(verb) else { return nil }
            self = .run(action)
        default:
            return nil
        }
    }
}

/// Shelf commands. `shelf=` picks a shelf by name or id. Without it, `add` uses the most
/// recently used shelf and the others act on every shelf. `shelf=new` always makes a new one.
public enum ShelfCommand: Equatable, Sendable {
    /// Adds files or folders by absolute path (`~` is allowed) and shows the shelf.
    /// With `mode=copy`, Tooki adds its own copies so the originals never move.
    /// A shelf name that doesn't exist yet makes a new shelf with that name.
    case add(paths: [String], asCopies: Bool, shelf: String?)
    /// Makes a new empty shelf and shows it.
    case new
    case show(shelf: String?)
    case hide(shelf: String?)
    case toggle(shelf: String?)
    /// Removes everything and closes the shelf. Only files Tooki created itself are deleted.
    case clear(shelf: String?)

    public static let newShelf = "new"

    init?(verb: String, query: [URLQueryItem]) {
        let shelf = query.last { $0.name == "shelf" }?.value.flatMap { $0.isEmpty ? nil : $0 }
        switch verb {
        case "add":
            let paths = query.filter { $0.name == "path" }.compactMap(\.value).filter { !$0.isEmpty }
            let mode = query.last { $0.name == "mode" }?.value ?? "original"
            guard !paths.isEmpty, ["original", "copy"].contains(mode) else { return nil }
            self = .add(paths: paths, asCopies: mode == "copy", shelf: shelf)
        case "new": self = .new
        case "show": self = .show(shelf: shelf)
        case "hide": self = .hide(shelf: shelf)
        case "toggle": self = .toggle(shelf: shelf)
        case "clear": self = .clear(shelf: shelf)
        default: return nil
        }
    }
}
