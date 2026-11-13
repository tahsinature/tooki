import AppKit
import SwiftUI

/// Colors and sizes shared by every floating panel.
/// Values follow Asyar's design tokens (`asyar-launcher/src/resources/styles/style.css`),
/// so the panels match its look in both light and dark mode.
enum PanelTheme {
    // MARK: Colors

    static let tint = adaptive(dark: (30, 30, 32, 0.65), light: (240, 240, 245, 0.65))
    static let tertiaryBackground = adaptive(dark: (50, 50, 52, 0.65), light: (245, 245, 247, 0.65))
    static let hoverBackground = adaptive(dark: (64, 64, 66, 0.55), light: (220, 220, 225, 0.5))
    static let selectedBackground = adaptive(dark: (120, 150, 245, 0.24), light: (42, 85, 214, 0.13))
    static let barBackground = adaptive(dark: (40, 40, 42, 1), light: (230, 230, 235, 1))
    static let popupBackground = adaptive(dark: (30, 30, 32, 0.8), light: (240, 240, 245, 0.8))

    static let primaryText = adaptive(dark: (255, 255, 255, 0.95), light: (15, 23, 42, 0.9))
    static let secondaryText = adaptive(dark: (235, 235, 245, 0.65), light: (60, 60, 67, 0.7))
    static let tertiaryText = adaptive(dark: (235, 235, 245, 0.4), light: (60, 60, 67, 0.35))

    static let separator = adaptive(dark: (90, 90, 95, 0.5), light: (60, 60, 67, 0.12))
    static let border = adaptive(dark: (90, 90, 95, 0.5), light: (60, 60, 67, 0.15))
    static let popupBorder = adaptive(dark: (255, 255, 255, 0.18), light: (60, 60, 67, 0.16))
    static let popupDivider = adaptive(dark: (255, 255, 255, 0.07), light: (60, 60, 67, 0.11))
    static let keycapBorder = adaptive(dark: (255, 255, 255, 0.22), light: (0, 0, 0, 0.2))
    static let selectedRim = adaptive(dark: (255, 255, 255, 0.03), light: (0, 0, 0, 0.025))
    static let selectionIndicator = adaptive(dark: (140, 165, 248, 1), light: (42, 85, 214, 1))
    static let compactTint = adaptive(dark: (41, 41, 44, 0.94), light: (245, 245, 247, 0.94))
    static let compactListBackground = adaptive(dark: (37, 37, 40, 0.8), light: (235, 235, 240, 0.65))

    static let accent = Color(red: 0, green: 122 / 255, blue: 1)
    static let accentFill = Color(red: 0, green: 113 / 255, blue: 237 / 255)
    static let danger = Color(red: 1, green: 59 / 255, blue: 48 / 255)

    // MARK: Sizes

    static let cornerRadius: CGFloat = 20
    /// Fixed, so a list-and-detail panel doesn't shrink around "No Matching Entries" and stay small afterwards.
    static let listDetailSize = CGSize(width: 750, height: 480)
    static let listWidth: CGFloat = 260
    static let headerHeight: CGFloat = 56
    static let footerHeight: CGFloat = 40
    static let rowHeight: CGFloat = 38
    static let rowRadius: CGFloat = 8
    static let rowIconSize: CGFloat = 22
    /// Space between a row's icon, title and accessories.
    static let rowSpacing: CGFloat = 12
    /// Inset of a list inside its pane. With the row's own 8pt padding, content sits 16pt from the edge.
    static let listInset: CGFloat = 8

    // MARK: Fonts

    static let queryFont = Font.system(size: 16, weight: .medium)
    static let queryTracking: CGFloat = -0.28
    static let rowTitleFont = Font.system(size: 13, weight: .medium)
    static let labelFont = Font.system(size: 12, weight: .medium)
    static let keycapFont = Font.system(size: 11, weight: .medium)
    static let monoFont = Font.system(size: 13, design: .monospaced)

    private typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    /// A color that switches with the panel's light or dark appearance.
    private static func adaptive(dark: RGBA, light: RGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(srgbRed: value.red / 255, green: value.green / 255, blue: value.blue / 255, alpha: value.alpha)
        })
    }
}
