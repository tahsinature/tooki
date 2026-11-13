import AppKit
import SwiftUI

/// A restrained, cool neutral palette that follows the Mac's appearance.
enum SettingsTheme {
    static let contentBackground = adaptive(dark: (29, 33, 41), light: (248, 249, 251))
    static let sidebarBackground = adaptive(dark: (36, 41, 50), light: (237, 239, 243))
    static let cardBackground = adaptive(dark: (36, 41, 49), light: (255, 255, 255))
    static let searchBackground = adaptive(dark: (49, 55, 66), light: (223, 226, 232))
    static let sidebarSelection = adaptive(dark: (49, 55, 65), light: (218, 223, 232))
    static let separator = Color.primary.opacity(0.065)
    static let cardBorder = Color.primary.opacity(0.035)
    static let secondaryBackground = Color.primary.opacity(0.045)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let controlRadius: CGFloat = 7
    static let rowTitleFont = Font.system(size: 13)
    static let rowDescriptionFont = Font.system(size: 12)

    private static func adaptive(dark: (Double, Double, Double), light: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        })
    }
}
