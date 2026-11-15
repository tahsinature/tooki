import AppKit
import SwiftUI

/// Shared typography, density and smoked-glass surfaces for Settings.
public enum SettingsTheme {
    public static let windowSize = CGSize(width: 800, height: 560)
    public static let sidebarWidth: CGFloat = 176
    public static let navigationHeight: CGFloat = 42
    public static let sectionSpacing: CGFloat = 12
    public static let pageInset: CGFloat = 16
    public static let cardRadius: CGFloat = 8
    public static let controlRadius: CGFloat = 6

    public static let contentBackground = DesignColor.adaptive(dark: (17, 18, 20, 0.87), light: (248, 249, 251, 0.87))
    public static let sidebarBackground = DesignColor.adaptive(dark: (27, 29, 33, 0.84), light: (237, 239, 243, 0.84))
    public static let opaqueBackground = DesignColor.adaptive(dark: (17, 18, 20, 1), light: (248, 249, 251, 1))
    public static let cardBackground = DesignColor.adaptive(dark: (255, 255, 255, 0.028), light: (255, 255, 255, 0.65))
    public static let searchBackground = Color.primary.opacity(0.06)
    public static let sidebarSelection = Color.primary.opacity(0.08)
    public static let separator = Color.primary.opacity(0.065)
    public static let cardBorder = Color.primary.opacity(0.07)
    public static let secondaryBackground = Color.primary.opacity(0.045)
    public static let primaryText = DesignColor.adaptive(dark: (235, 236, 239, 1), light: (31, 36, 48, 1))
    public static let secondaryText = DesignColor.adaptive(dark: (180, 182, 191, 1), light: (91, 99, 114, 1))
    public static let tertiaryText = DesignColor.adaptive(dark: (145, 148, 159, 1), light: (115, 123, 136, 1))

    public static let rowTitleFont = font(12)
    public static let rowDescriptionFont = font(10)
    public static let sidebarFont = font(11)
    public static let sectionFont = font(11, weight: .medium)
    public static let controlFont = font(10.5)
    public static let metadataFont = font(9.5)

    public static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }

}
