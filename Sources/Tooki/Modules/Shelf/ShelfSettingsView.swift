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
        Form {
            PageHeader(page: .shelf)

            ShelfListSection(app: app)
                .disabled(!config.value.shelf.enabled)

            ShelfHowItWorksSection()

            Section("Settings") {
                Toggle("Enable the shelf", isOn: $config.value.shelf.enabled)
                Group {
                    Toggle(isOn: $config.value.shelf.shiftDragOpens) {
                        Text("Show while Shift-dragging")
                        Text("Hold Shift while dragging files, text or images in any app.")
                    }
                    Toggle(isOn: $config.value.shelf.removeAfterDragOut) {
                        Text("Remove items after dragging them out")
                        Text("Turn off to keep items, so you can drag them out again.")
                    }
                    Toggle(isOn: $config.value.shelf.closeWhenEmpty) {
                        Text("Close a shelf when it's empty")
                        Text("Turn off to keep an empty shelf open, ready for the next drop.")
                    }
                }
                .disabled(!config.value.shelf.enabled)
            }

            Section {
                LabeledContent {
                    Button("Open Shortcuts", action: onOpenShortcuts)
                } label: {
                    Text("Shortcut")
                    Text(shortcutText)
                }
            }

            Section {
                LabeledContent {
                    Button("Open General", action: onOpenGeneral)
                } label: {
                    Text("Use from other apps")
                    Text("Add files from scripts, fzf or yazi with tooki:// links. They're listed under General › URL Scheme.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutText: String {
        let shortcut = config.value.shortcuts.first { HotkeyAction($0.action) == .toggleShelf && $0.enabled }
        guard let keys = shortcut?.keys, let combo = KeyCombo(keys) else {
            return "No shortcut yet. Bind “Show or Hide Shelf” to open the shelf from the keyboard."
        }
        return "Press \(combo.symbols.joined()) to show or hide every shelf, or open a new one when there are none."
    }
}
