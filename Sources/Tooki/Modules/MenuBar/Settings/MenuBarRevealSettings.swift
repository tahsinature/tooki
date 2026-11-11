import SwiftUI
import TookiKit

/// Hover, click and scroll triggers on empty menu bar space.
struct MenuBarRevealSettings: View {
    @Binding var menuBar: MenuBarConfig

    private let hoverDelays = [0.0, 0.2, 0.5, 1.0]

    var body: some View {
        SettingsSection("Reveal") {
            SettingsToggleRow("Show when hovering over empty menu bar space", isOn: $menuBar.showOnHover)
            if menuBar.showOnHover {
                SettingsRow("Hover delay") {
                    Picker("Hover delay", selection: $menuBar.showOnHoverDelay) {
                        ForEach(hoverDelays, id: \.self) { delay in
                            Text(delay == 0 ? "None" : "\(delay.formatted()) seconds").tag(delay)
                        }
                    }
                    .settingsMenuPicker()
                }
            }
            SettingsToggleRow("Show or hide by clicking empty menu bar space", isOn: $menuBar.showOnClick)
            SettingsToggleRow("Show or hide by scrolling on the menu bar", isOn: $menuBar.showOnScroll)
        } footer: {
            Text("Icons shown by hovering hide again when the pointer leaves the menu bar.")
        }
    }
}
