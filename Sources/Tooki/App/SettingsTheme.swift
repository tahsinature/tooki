import SwiftUI

/// The purple palette is scoped to the settings window.
enum SettingsTheme {
    static let background = Color(red: 0.09, green: 0.065, blue: 0.12)
    static let sidebar = Color(red: 0.145, green: 0.11, blue: 0.22)
    static let surface = Color(red: 0.16, green: 0.125, blue: 0.19)
    static let accent = Color(red: 0.69, green: 0.47, blue: 0.92)
    static let secondaryText = Color(red: 0.76, green: 0.68, blue: 0.82)
    static let border = Color.white.opacity(0.09)
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.27, green: 0.13, blue: 0.36), Color(red: 0.13, green: 0.09, blue: 0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
