import AppKit
import SwiftUI

/// Shared typography, density and smoked-glass surfaces for Settings.
enum SettingsTheme {
    static let windowSize = CGSize(width: 800, height: 560)
    static let sidebarWidth: CGFloat = 176
    static let navigationHeight: CGFloat = 42
    static let sectionSpacing: CGFloat = 12
    static let pageInset: CGFloat = 16
    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 6

    static let contentBackground = adaptive(dark: (17, 18, 20, 0.87), light: (248, 249, 251, 0.87))
    static let sidebarBackground = adaptive(dark: (27, 29, 33, 0.84), light: (237, 239, 243, 0.84))
    static let opaqueBackground = adaptive(dark: (17, 18, 20, 1), light: (248, 249, 251, 1))
    static let cardBackground = adaptive(dark: (255, 255, 255, 0.028), light: (255, 255, 255, 0.65))
    static let searchBackground = Color.primary.opacity(0.06)
    static let sidebarSelection = Color.primary.opacity(0.08)
    static let separator = Color.primary.opacity(0.065)
    static let cardBorder = Color.primary.opacity(0.07)
    static let secondaryBackground = Color.primary.opacity(0.045)
    static let primaryText = adaptive(dark: (235, 236, 239, 1), light: (31, 36, 48, 1))
    static let secondaryText = adaptive(dark: (180, 182, 191, 1), light: (91, 99, 114, 1))
    static let tertiaryText = adaptive(dark: (145, 148, 159, 1), light: (115, 123, 136, 1))

    static let rowTitleFont = font(12)
    static let rowDescriptionFont = font(10)
    static let sidebarFont = font(11)
    static let sectionFont = font(11, weight: .medium)
    static let controlFont = font(10.5)
    static let metadataFont = font(9.5)

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }

    private typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    private static func adaptive(dark: RGBA, light: RGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.red / 255, green: value.green / 255,
                           blue: value.blue / 255, alpha: value.alpha)
        })
    }
}
