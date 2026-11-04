import SwiftUI
import TookiKit

struct HyperKeyView: View {
    @Bindable var config: JSONDocument<TookiConfig>

    var body: some View {
        Form {
            Section {
                Toggle("Use Caps Lock as Hyper key", isOn: $config.value.hyperKey.enabled)
            } footer: {
                Text("While held, Caps Lock acts as Control + Option + Shift + Command (⌃⌥⇧⌘), so other apps can use it in their shortcuts too. A quick tap still turns Caps Lock on or off.")
                    .foregroundStyle(.secondary)
            }

            Section("Tooki shortcuts") {
                ForEach($config.value.hyperKey.bindings.indices, id: \.self) { index in
                    BindingRow(binding: $config.value.hyperKey.bindings[index]) {
                        config.value.hyperKey.bindings.remove(at: index)
                    }
                }
                Button("Add Shortcut", systemImage: "plus") {
                    config.value.hyperKey.bindings.append(HotkeyBinding(key: "", action: "open:com.apple.mail"))
                }
            }

            Section("Available actions") {
                ForEach(HotkeyAction.documentation.sorted(by: { $0.key < $1.key }), id: \.key) { action, description in
                    LabeledContent {
                        Text(description).foregroundStyle(.secondary)
                    } label: {
                        Text(action).font(.body.monospaced())
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct BindingRow: View {
    @Binding var binding: HotkeyBinding
    let onDelete: () -> Void

    private var isValid: Bool {
        KeyCode.forKey(binding.key) != nil && HotkeyAction(binding.action) != nil
    }

    var body: some View {
        HStack {
            Text("Hyper +").foregroundStyle(.secondary)
            TextField("key", text: $binding.key)
                .frame(width: 60)
                .font(.body.monospaced())
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            TextField("action", text: $binding.action)
                .font(.body.monospaced())
            if !isValid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Unknown key or action")
            }
            Button("Remove", systemImage: "minus.circle", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .textFieldStyle(.roundedBorder)
    }
}
