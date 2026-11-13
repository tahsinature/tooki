import SwiftUI

/// One native blur behind both Settings panes; each pane supplies its own tint.
struct SettingsGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            SettingsTheme.opaqueBackground
        } else {
            VisualEffectBackground(material: .hudWindow, cornerRadius: 0)
        }
    }
}
