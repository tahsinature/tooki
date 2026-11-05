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

public enum ShelfCommand: Equatable, Sendable {
    /// Adds files or folders by absolute path (`~` is allowed) and shows the shelf.
    /// With `mode=copy`, Tooki adds its own copies so the originals never move.
    case add(paths: [String], asCopies: Bool)
    case show
    case hide
    case toggle
    /// Removes everything and hides the shelf. Only files Tooki created itself are deleted.
    case clear

    init?(verb: String, query: [URLQueryItem]) {
        switch verb {
        case "add":
            let paths = query.filter { $0.name == "path" }.compactMap(\.value).filter { !$0.isEmpty }
            let mode = query.last { $0.name == "mode" }?.value ?? "original"
            guard !paths.isEmpty, ["original", "copy"].contains(mode) else { return nil }
            self = .add(paths: paths, asCopies: mode == "copy")
        case "show": self = .show
        case "hide": self = .hide
        case "toggle": self = .toggle
        case "clear": self = .clear
        default: return nil
        }
    }
}
