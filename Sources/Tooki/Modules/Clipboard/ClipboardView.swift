import SwiftUI
import TookiKit

struct ClipboardView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let history: ClipboardHistory

    var body: some View {
        Form {
            PageHeader(page: .clipboard)

            Section {
                Toggle("Record clipboard history", isOn: $config.value.clipboard.enabled)
                Stepper(value: $config.value.clipboard.maxItems, in: 10...2000, step: 10) {
                    LabeledContent("Keep last", value: "\(config.value.clipboard.maxItems) items")
                }
                Stepper(value: $config.value.clipboard.maxImages, in: 0...500, step: 10) {
                    LabeledContent("Of which images", value: config.value.clipboard.maxImages == 0 ? "Off" : "\(config.value.clipboard.maxImages)")
                }
                Toggle("Remember history after restart", isOn: $config.value.clipboard.persistHistory)
            } footer: {
                Text("Open with Hyper + V. Text inside copied images is searchable; it is read on this Mac. Passwords and content from ignored apps are never recorded. History stays on this Mac and is not part of your config folder.")
                    .foregroundStyle(.secondary)
            }

            Section("Ignored apps (bundle identifiers)") {
                StringListEditor(items: $config.value.clipboard.ignoredApps, placeholder: "com.example.app")
            }

            Section("History") {
                LabeledContent("Saved items", value: "\(history.items.count)")
                Button("Clear History", role: .destructive) { history.clear() }
                    .disabled(history.items.isEmpty)
            }
        }
        .formStyle(.grouped)
    }
}

/// Editable list of plain strings, used for bundle identifier lists.
struct StringListEditor: View {
    @Binding var items: [String]
    let placeholder: String
    @ViewState private var newItem = ""

    var body: some View {
        ForEach(items, id: \.self) { item in
            HStack {
                Text(item).font(.body.monospaced())
                Spacer()
                Button("Remove", systemImage: "minus.circle") { items.removeAll { $0 == item } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        }
        HStack {
            TextField(placeholder, text: $newItem)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .onSubmit(add)
            Button("Add", action: add).disabled(newItem.isEmpty)
        }
    }

    private func add() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !items.contains(trimmed) else { return }
        items.append(trimmed)
        newItem = ""
    }
}
