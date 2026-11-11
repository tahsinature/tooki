import TookiKit

extension ClipboardContentType {
    /// Shown in the "All Types" filter menu.
    var pluralLabel: String {
        switch self {
        case .text: "Text"
        case .link: "Links"
        case .color: "Colors"
        case .image: "Images"
        case .file: "Files"
        }
    }
}
