import AppKit
import SwiftUI
import TookiKit

struct ShelfSettingsView: View {
    let app: AppController
    let onOpenShortcuts: () -> Void
    let onOpenGeneral: () -> Void

    private var config: JSONDocument<TookiConfig> { app.config }
    private var shelf: Shelf { app.shelf }

    var body: some View {
        @Bindable var config = config
        Form {
            PageHeader(page: .shelf)

            Section {
                HStack(spacing: 14) {
                    Image(systemName: shelf.isEmpty ? "tray" : "tray.full.fill")
                        .font(.largeTitle)
                        .foregroundStyle(shelf.isEmpty ? Color.secondary : Color.accentColor)
                    VStack(alignment: .leading) {
                        Text(shelf.isEmpty ? "The shelf is empty" : "\(ShelfText.itemCount(shelf.items.count).lowercased()) on the shelf")
                            .font(.headline)
                        Text(shelf.isEmpty ? "Hold Shift while dragging anything to drop it here." : sizeText)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show") { app.showShelf() }
                    Button("Clear") { app.clearShelf() }.disabled(shelf.isEmpty)
                }
                .disabled(!config.value.shelf.enabled)
            }

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
                        Text("The shelf closes once it's empty.")
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

    private var sizeText: String {
        ByteCountFormatter.string(fromByteCount: shelf.totalBytes, countStyle: .file)
    }

    private var shortcutText: String {
        let shortcut = config.value.shortcuts.first { HotkeyAction($0.action) == .toggleShelf && $0.enabled }
        guard let keys = shortcut?.keys, let combo = KeyCombo(keys) else {
            return "No shortcut yet. Bind “Show or Hide Shelf” to open the shelf from the keyboard."
        }
        return "Press \(combo.symbols.joined()) to show or hide the shelf."
    }
}
