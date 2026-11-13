import SwiftUI
import TookiKit

struct PanelNavigationSettings: View {
    let app: AppController

    var body: some View {
        @Bindable var config = app.config
        SettingsSection("Panel navigation", footerTitle: "How panel navigation works") {
            SettingsRow("Main shortcut opens") {
                Picker("Main shortcut opens", selection: $config.value.panelNavigation.resumeLastPanel) {
                    Text("Last used panel").tag(true)
                    Text("Root Search").tag(false)
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow("Return to Root Search", description: "Works anywhere in a Tooki panel.") {
                HotkeyRecorder(
                    combo: KeyCombo(config.value.panelNavigation.rootSearchShortcut),
                    validate: problem,
                    onRecordingChange: app.setRecordingShortcut
                ) { combo in
                    config.value.panelNavigation.rootSearchShortcut = combo?.description ?? ""
                }
            }
        } footer: {
            Text("Last used panel keeps your search, filters, selection and scroll position until Tooki quits. Esc clears the current search, then returns to the previous Root Search. The return shortcut starts a fresh Root Search and keeps snippet drafts available in Snippets.")
        }
    }

    private func problem(with combo: KeyCombo) -> String? {
        if combo.isReservedBySystem {
            return "That is a standard macOS shortcut"
        }
        if ["cmd+k", "cmd+p", "cmd+e", "cmd+d", "cmd+o", "cmd+y", "cmd+return"].contains(combo.description) {
            return "Already used by a panel action"
        }
        if app.config.value.shortcuts.contains(where: { $0.enabled && KeyCombo($0.keys) == combo }) {
            return "Already used by a global Tooki shortcut"
        }
        return nil
    }
}
