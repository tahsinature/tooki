import SwiftUI
import TookiKit

/// Snippet settings. Snippets themselves are browsed, written and edited in the snippets panel.
struct SnippetsView: View {
    let app: AppController
    let onOpenShortcuts: () -> Void

    private var config: JSONDocument<TookiConfig> { app.config }

    var body: some View {
        @Bindable var config = config
        SettingsScrollPage {
            SettingsSection("Your snippets") {
                SettingsRow(countText, description: "Search, copy, paste, pin and edit them in the snippets panel.") {
                    HStack(spacing: 8) {
                        Button("New Snippet") { app.createSnippet() }
                        Button("Open Snippets") { app.toggleSnippets() }
                    }
                }
            }

            SettingsSection("Settings") {
                SettingsToggleRow("Enable snippets", isOn: $config.value.snippets.enabled)
                SettingsToggleRow(
                    "Expand keywords as you type",
                    description: "Typing a snippet's keyword in any app, like ;date, replaces it with the snippet.",
                    isOn: $config.value.snippets.keywordExpansion
                )
                .disabled(!config.value.snippets.enabled)
                SettingsRow("Shortcut", description: shortcutText) {
                    Button("Open Shortcuts", action: onOpenShortcuts)
                }
            }

            SettingsSection("Placeholders") {
                ForEach(SnippetPlaceholder.all) { placeholder in
                    SettingsRow(placeholder.title, description: placeholder.detail) {
                        Text(placeholder.token)
                            .font(.callout.monospaced())
                            .foregroundStyle(SettingsTheme.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            } footer: {
                Text("Placeholders are filled in when a snippet is copied, pasted or expanded.")
            }
        }
    }

    private var countText: String {
        let count = app.snippets.value.count
        return count == 1 ? "1 snippet" : "\(count.formatted()) snippets"
    }

    private var shortcutText: String {
        let shortcut = config.value.shortcuts.first { HotkeyAction($0.action) == .snippets && $0.enabled }
        guard let keys = shortcut?.keys, let combo = KeyCombo(keys) else {
            return "No shortcut yet. Bind “Search Snippets” to open the snippets panel from the keyboard."
        }
        return "Press \(combo.symbols.joined()) to open the snippets panel."
    }
}
