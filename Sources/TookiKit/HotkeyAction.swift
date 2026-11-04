/// Actions that can be bound to Hyper + key in `config.json`.
public enum HotkeyAction: Equatable, Sendable {
    case search
    case clipboard
    case toggleKeepAwake
    case toggleMenuBar
    case searchMenuBar
    case settings
    /// Opens an app by bundle identifier (`com.apple.mail`) or path (`/Applications/Safari.app`).
    case open(String)

    public init?(_ text: String) {
        switch text {
        case "search": self = .search
        case "clipboard": self = .clipboard
        case "keepAwake.toggle": self = .toggleKeepAwake
        case "menuBar.toggle": self = .toggleMenuBar
        case "menuBar.search": self = .searchMenuBar
        case "settings": self = .settings
        default:
            guard text.hasPrefix("open:") else { return nil }
            let target = String(text.dropFirst("open:".count))
            guard !target.isEmpty else { return nil }
            self = .open(target)
        }
    }

    public static let documentation = [
        "search": "Open the search panel",
        "clipboard": "Open clipboard history",
        "keepAwake.toggle": "Turn Keep Awake on or off",
        "menuBar.toggle": "Show or hide hidden menu bar icons",
        "menuBar.search": "Search and click menu bar items, hidden or shown",
        "settings": "Open Tooki settings",
        "open:<bundle id or path>": "Open an app, e.g. open:com.apple.mail",
    ]
}
