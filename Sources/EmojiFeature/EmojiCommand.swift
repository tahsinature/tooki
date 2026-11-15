/// Portable action identity and labels used by the picker and its filtered action menu.
public enum EmojiCommand: String, CaseIterable, Equatable, Sendable {
    case copy, paste, copyShortcode

    public var title: String {
        switch self {
        case .copy: "Copy Emoji"
        case .paste: "Paste Emoji"
        case .copyShortcode: "Copy Shortcode"
        }
    }
}
