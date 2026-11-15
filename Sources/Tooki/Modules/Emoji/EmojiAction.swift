import EmojiFeature
import TookiDesignSystem

typealias EmojiAction = EmojiCommand

// The application owns the design-system presentation of portable feature actions.
extension EmojiCommand: PanelActionItem {
    public var id: String { rawValue }
    public var isDestructive: Bool { false }

    public var icon: PanelIcon {
        switch self {
        case .paste: .symbol("doc.on.clipboard")
        case .copy: .symbol("doc.on.doc")
        case .copyShortcode: .symbol("textformat")
        }
    }

    public var shortcut: String {
        switch self {
        case .copy: "↵"
        case .paste: "⌘↵"
        case .copyShortcode: ""
        }
    }
}

