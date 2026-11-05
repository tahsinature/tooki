import SwiftUI
import TookiKit

struct HyperKeyView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let onOpenShortcuts: () -> Void

    var body: some View {
        Form {
            PageHeader(page: .hyperKey)

            Section {
                HyperKeyboardIllustration(isEnabled: config.value.hyperKey.enabled)
                Toggle("Use Caps Lock as Hyper key", isOn: $config.value.hyperKey.enabled)
            }

            Section("How it works") {
                InfoRow(symbol: "hand.raised.fill", color: .purple, title: "Hold Caps Lock") {
                    Text("It acts as Control + Option + Shift + Command (⌃⌥⇧⌘). No app uses that combination, so your shortcuts never clash.")
                }
                InfoRow(symbol: "capslock.fill", color: .blue, title: "Tap Caps Lock") {
                    Text("A quick tap still turns Caps Lock on or off.")
                }
                InfoRow(symbol: "app.connected.to.app.below.fill", color: .green, title: "Works in every app") {
                    Text("Other apps see ⌃⌥⇧⌘, so you can use Hyper in their shortcuts too.")
                }
            }

            Section {
                LabeledContent {
                    Button("Open Shortcuts", action: onOpenShortcuts)
                } label: {
                    Text("Shortcuts")
                    Text("Assign Hyper combos to Tooki features and apps.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct InfoRow<Detail: View>: View {
    let symbol: String
    let color: Color
    let title: String
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                detail
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
