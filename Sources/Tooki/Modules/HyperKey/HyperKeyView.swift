import SwiftUI
import TookiKit

struct HyperKeyView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let onOpenShortcuts: () -> Void

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Hyper Key") {
                SettingsToggleRow(
                    "Use Caps Lock as Hyper key",
                    description: "Hold for Hyper. Tap to toggle Caps Lock.",
                    isOn: $config.value.hyperKey.enabled
                )
            }

            SettingsSection("How it works") {
                HyperKeyInstructions()
            }

            SettingsSection("Shortcuts") {
                SettingsRow("Hyper shortcuts", description: "Assign Hyper combos to Tooki features and apps.") {
                    Button("Open Shortcuts", systemImage: "arrow.right", action: onOpenShortcuts)
                }
            }
        }
    }
}
