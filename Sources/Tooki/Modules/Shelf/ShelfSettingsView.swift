import AppKit
import SwiftUI
import TookiKit

struct ShelfSettingsView: View {
    let app: AppController
    let onOpenShortcuts: () -> Void
    let onOpenGeneral: () -> Void

    private var config: JSONDocument<TookiConfig> { app.config }

    var body: some View {
        @Bindable var config = config
        SettingsScrollPage {
            ShelfListSection(app: app)
                .disabled(!config.value.shelf.enabled)

            ShelfHowItWorksSection()

            SettingsSection("Settings") {
                SettingsToggleRow("Enable the shelf", isOn: $config.value.shelf.enabled)
                Group {
                    SettingsToggleRow(
                        "Show while Shift-dragging",
                        description: "Hold Shift while dragging files, text or images in any app.",
                        isOn: $config.value.shelf.shiftDragOpens
                    )
                    SettingsToggleRow(
                        "Remove items after dragging them out",
                        description: "Turn off to keep items, so you can drag them out again.",
                        isOn: $config.value.shelf.removeAfterDragOut
                    )
                }
                .disabled(!config.value.shelf.enabled)
            }

            SettingsSection("Shortcuts and links") {
                SettingsRow("Shortcut", description: shortcutText) {
                    Button("Open Shortcuts", action: onOpenShortcuts)
                }
                SettingsRow(
                    "Use from other apps",
                    description: "Add files from scripts, fzf or yazi with tooki:// links. They're listed under General › URL Scheme."
                ) {
                    Button("Open General", action: onOpenGeneral)
                }
            }
        }
    }

    private var shortcutText: String {
        let shortcut = config.value.shortcuts.first { HotkeyAction($0.action) == .shelfManager && $0.enabled }
        guard let keys = shortcut?.keys, let combo = KeyCombo(keys) else {
            return "No shortcut yet. Bind “Shelf Manager” to open your shelves from the keyboard."
        }
        return "Press \(combo.symbols.joined()) to open the Shelf Manager. Press ⌘S there to show or hide every shelf."
    }
}
