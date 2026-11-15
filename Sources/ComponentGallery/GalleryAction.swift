import TookiDesignSystem

struct GalleryItem: Identifiable {
    let id: String
}

enum GalleryAction: String, CaseIterable, PanelActionItem {
    case copy, pin, delete

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var shortcut: String {
        switch self {
        case .copy: "↵"
        case .pin: "⇧⌘P"
        case .delete: "⌃X"
        }
    }
    var icon: PanelIcon {
        .symbol(self == .delete ? "trash" : self == .pin ? "pin" : "doc.on.doc")
    }
    var isDestructive: Bool { self == .delete }
}
