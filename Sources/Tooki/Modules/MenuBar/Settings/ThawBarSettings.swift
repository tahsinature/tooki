import SwiftUI
import TookiKit

/// The Thaw Bar: hidden icons in a strip below the menu bar instead of in it.
struct ThawBarSettings: View {
    @Binding var menuBar: MenuBarConfig

    var body: some View {
        SettingsSection("Thaw Bar") {
            SettingsToggleRow("Show hidden icons below the menu bar", isOn: $menuBar.useThawBar)
            if menuBar.useThawBar {
                SettingsRow("Location") {
                    Picker("Location", selection: $menuBar.thawBarLocation) {
                        Text("Under the pointer").tag(ThawBarLocation.underMouse)
                        Text("Under the divider").tag(ThawBarLocation.underDivider)
                        Text("Right side").tag(ThawBarLocation.rightAligned)
                    }
                    .settingsMenuPicker()
                }
                SettingsRow("Background") {
                    Picker("Background", selection: $menuBar.thawBarStyle) {
                        Text("Translucent").tag(ThawBarStyle.material)
                        Text("Solid").tag(ThawBarStyle.solid)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsToggleRow("Show pictures of the icons", isOn: $menuBar.captureIconImages)
                    .onChange(of: menuBar.captureIconImages) { _, isOn in
                        if isOn, !MenuBarItemImageCapture.isAllowed { MenuBarItemImageCapture.requestAccess() }
                    }
            }
        } footer: {
            Text("Useful when the notch leaves no room. Pictures of the icons need the Screen Recording permission; without it, app icons are shown.")
        }
    }
}
