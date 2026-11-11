/// Actions that `shortcuts` in `config.json` can run.
public enum HotkeyAction: Equatable, Sendable {
    case search
    case clipboard
    case snippets
    case emoji
    case shelfManager
    case searchMenuBar
    /// Opens an app by bundle identifier (`com.apple.mail`) or path (`/Applications/Safari.app`).
    case open(String)

    public init?(_ text: String) {
        switch text {
        case "search": self = .search
        case "clipboard": self = .clipboard
        case "snippets": self = .snippets
        case "emoji": self = .emoji
        case "shelf.manager": self = .shelfManager
        case "menuBar.search": self = .searchMenuBar
        default:
            guard text.hasPrefix("open:") else { return nil }
            let target = String(text.dropFirst("open:".count))
            guard !target.isEmpty else { return nil }
            self = .open(target)
        }
    }

    /// Tooki's own actions, in the order the Shortcuts page lists them.
    public static let builtIns = [
        "search", "clipboard", "snippets", "emoji", "shelf.manager", "menuBar.search",
    ]
}
