import SwiftUI
import TookiKit

struct MenuBarView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let organizer: MenuBarOrganizer
    let arranger: MenuBarArranger

    private let autoHideOptions = [0, 5, 10, 30, 60]

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Organize") {
                SettingsToggleRow("Organize menu bar icons", isOn: $config.value.menuBar.enabled)
                SettingsToggleRow("Hide icons when Tooki starts", isOn: $config.value.menuBar.startCollapsed)
                SettingsRow("Hide again after") {
                    Picker("Hide again after", selection: $config.value.menuBar.autoHideSeconds) {
                        ForEach(autoHideOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "Never" : "\(seconds) seconds").tag(seconds)
                        }
                    }
                    .settingsMenuPicker()
                }
                SettingsToggleRow("Always-hidden section", isOn: $config.value.menuBar.alwaysHiddenSection)
            } footer: {
                Text("Icons left of the second divider stay hidden until you show all icons (⌥-click the menu bar, or use the button below).")
            }

            SettingsSection {
                SettingsRow("Hidden icons") {
                    HStack {
                        Button(organizer.isCollapsed ? "Show" : "Hide") { organizer.toggle() }
                        if organizer.hasAlwaysHiddenSection {
                            Button("Show All") { organizer.showAll() }
                        }
                    }
                    .disabled(!organizer.isInstalled)
                }
            } footer: {
                Text("Show or hide icons from Tooki’s menu or with Hyper + M. No extra menu bar button is added.")
            }

            MenuBarRevealSettings(menuBar: $config.value.menuBar)
            ThawBarSettings(menuBar: $config.value.menuBar)
            MenuBarAppearanceSettings(menuBar: $config.value.menuBar)
            MenuBarLayoutEditor(config: config, organizer: organizer, arranger: arranger)

            SettingsSection("Arranging by hand") {
                SettingsCardRow {
                    Label("Show hidden icons first. Hold ⌘ and drag an icon left of a divider to hide it, or right of it to show it.", systemImage: "hand.draw")
                }
                SettingsCardRow {
                    Label("Click “Reload from Menu Bar”, then “Apply & Save” to keep that arrangement in config.json.", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}
