import AppKit
import SwiftUI

/// Shared light/dark color construction for panel and settings themes.
enum DesignColor {
    typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    /// A color that switches with the panel's light or dark appearance.
    static func adaptive(dark: RGBA, light: RGBA) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(srgbRed: value.red / 255, green: value.green / 255, blue: value.blue / 255, alpha: value.alpha)
        })
    }
}
