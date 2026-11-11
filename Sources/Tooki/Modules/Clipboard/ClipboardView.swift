import SwiftUI
import TookiKit

struct ClipboardView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let history: ClipboardHistory

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Clipboard History") {
                SettingsToggleRow("Record clipboard history", isOn: $config.value.clipboard.enabled)
                SettingsRow("Keep last") {
                    SettingsStepper(
                        title: "Keep last",
                        value: $config.value.clipboard.maxItems,
                        range: 10...2000,
                        step: 10,
                        valueLabel: "\(config.value.clipboard.maxItems) items"
                    )
                }
                SettingsRow("Of which images") {
                    SettingsStepper(
                        title: "Of which images",
                        value: $config.value.clipboard.maxImages,
                        range: 0...500,
                        step: 10,
                        valueLabel: config.value.clipboard.maxImages == 0 ? "Off" : "\(config.value.clipboard.maxImages)"
                    )
                }
                SettingsToggleRow("Remember history after restart", isOn: $config.value.clipboard.persistHistory)
            } footer: {
                Text("Open with Hyper + V. Text inside copied images is searchable; it is read on this Mac. Passwords and content from ignored apps are never recorded. History stays on this Mac and is not part of your config folder.")
            }

            SettingsSection("Ignored apps (bundle identifiers)") {
                StringListEditor(items: $config.value.clipboard.ignoredApps, placeholder: "com.example.app")
            }

            SettingsSection("History") {
                SettingsRow("Saved items") {
                    HStack(spacing: 12) {
                        Text("\(history.items.count)")
                            .foregroundStyle(SettingsTheme.secondaryText)
                            .monospacedDigit()
                        Button("Clear History", role: .destructive) { history.clear() }
                            .disabled(history.items.isEmpty)
                    }
                }
            }
        }
    }
}

/// Editable list of plain strings, used for bundle identifier lists.
struct StringListEditor: View {
    @Binding var items: [String]
    let placeholder: String
    @ViewState private var newItem = ""

    var body: some View {
        ForEach(items, id: \.self) { item in
            SettingsCardRow {
                HStack {
                    Text(item).font(.body.monospaced())
                    Spacer()
                    Button("Remove", systemImage: "minus.circle") { items.removeAll { $0 == item } }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
        }
        SettingsCardRow {
            HStack {
                TextField(placeholder, text: $newItem)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onSubmit(add)
                Button("Add", action: add).disabled(newItem.isEmpty)
            }
        }
    }

    private func add() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !items.contains(trimmed) else { return }
        items.append(trimmed)
        newItem = ""
    }
}
