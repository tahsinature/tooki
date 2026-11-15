import AppKit
import SwiftUI

/// Colors and sizes shared by every floating panel.
/// Values follow Asyar's design tokens (`asyar-launcher/src/resources/styles/style.css`),
/// so the panels match its look in both light and dark mode.
public enum PanelTheme {
    // MARK: Colors

    public static let tint = DesignColor.adaptive(dark: (30, 30, 32, 0.65), light: (240, 240, 245, 0.65))
    public static let tertiaryBackground = DesignColor.adaptive(dark: (50, 50, 52, 0.65), light: (245, 245, 247, 0.65))
    public static let hoverBackground = DesignColor.adaptive(dark: (64, 64, 66, 0.55), light: (220, 220, 225, 0.5))
    public static let selectedBackground = DesignColor.adaptive(dark: (120, 150, 245, 0.24), light: (42, 85, 214, 0.13))
    public static let barBackground = DesignColor.adaptive(dark: (40, 40, 42, 1), light: (230, 230, 235, 1))
    public static let popupBackground = DesignColor.adaptive(dark: (30, 30, 32, 0.8), light: (240, 240, 245, 0.8))

    public static let primaryText = DesignColor.adaptive(dark: (255, 255, 255, 0.95), light: (15, 23, 42, 0.9))
    public static let secondaryText = DesignColor.adaptive(dark: (235, 235, 245, 0.65), light: (60, 60, 67, 0.7))
    public static let tertiaryText = DesignColor.adaptive(dark: (235, 235, 245, 0.4), light: (60, 60, 67, 0.35))

    public static let separator = DesignColor.adaptive(dark: (90, 90, 95, 0.5), light: (60, 60, 67, 0.12))
    public static let border = DesignColor.adaptive(dark: (90, 90, 95, 0.5), light: (60, 60, 67, 0.15))
    public static let popupBorder = DesignColor.adaptive(dark: (255, 255, 255, 0.18), light: (60, 60, 67, 0.16))
    public static let popupDivider = DesignColor.adaptive(dark: (255, 255, 255, 0.07), light: (60, 60, 67, 0.11))
    public static let keycapBorder = DesignColor.adaptive(dark: (255, 255, 255, 0.22), light: (0, 0, 0, 0.2))
    public static let selectedRim = DesignColor.adaptive(dark: (255, 255, 255, 0.03), light: (0, 0, 0, 0.025))
    public static let selectionIndicator = DesignColor.adaptive(dark: (140, 165, 248, 1), light: (42, 85, 214, 1))

    public static let accent = Color(red: 0, green: 122 / 255, blue: 1)
    public static let accentFill = Color(red: 0, green: 113 / 255, blue: 237 / 255)
    public static let danger = Color(red: 1, green: 59 / 255, blue: 48 / 255)

    // MARK: Sizes

    public static let cornerRadius: CGFloat = 20
    /// Shared by tool views and their windows, including panels showing an empty state.
    public static let size = CGSize(width: 750, height: 480)
    public static let listWidth: CGFloat = 260
    public static let headerHeight: CGFloat = 56
    public static let footerHeight: CGFloat = 40
    public static let rowHeight: CGFloat = 38
    public static let rowRadius: CGFloat = 8
    public static let rowIconSize: CGFloat = 22
    /// Space between a row's icon, title and accessories.
    public static let rowSpacing: CGFloat = 12
    /// Inset of a list inside its pane. With the row's own 8pt padding, content sits 16pt from the edge.
    public static let listInset: CGFloat = 8

    public static let rowHorizontalInset: CGFloat = 8
    public static let sectionSpacing: CGFloat = 10
    public static let firstSectionHeight: CGFloat = 24
    public static let sectionHeight: CGFloat = 32

    // MARK: Fonts

    public static let queryFont = Font.system(size: 16, weight: .medium)
    public static let queryTracking: CGFloat = -0.28
    public static let rowTitleFont = Font.system(size: 13, weight: .medium)
    public static let sectionFont = Font.system(size: 11, weight: .semibold)
    public static let labelFont = Font.system(size: 12, weight: .medium)
    public static let keycapFont = Font.system(size: 11, weight: .medium)
    public static let monoFont = Font.system(size: 13, design: .monospaced)

}
