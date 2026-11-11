import AppKit
import SwiftUI

/// Colors and sizes for the settings window. Colors are system colors, so the window follows
/// light and dark mode like the rest of macOS.
enum SettingsTheme {
    // MARK: Colors

    /// A faint fill for small boxes inside rows, like a command or a comparison tile.
    static let secondaryBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.35)

    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    // MARK: Sizes

    static let controlRadius: CGFloat = 6

    // MARK: Fonts

    static let rowTitleFont = Font.body
    static let rowDescriptionFont = Font.subheadline
}
