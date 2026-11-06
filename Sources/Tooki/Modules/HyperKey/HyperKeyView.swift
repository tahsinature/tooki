import SwiftUI
import TookiKit

struct HyperKeyView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let onOpenShortcuts: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                FeatureHeader(page: .hyperKey)

                Toggle(isOn: $config.value.hyperKey.enabled) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Use Caps Lock as Hyper key").font(.headline)
                        Text("Hold for Hyper. Tap to toggle Caps Lock.")
                            .font(.callout)
                            .foregroundStyle(SettingsTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .toggleStyle(.switch)
                .padding(20)
                .groupedCard()

                VStack(alignment: .leading, spacing: 20) {
                    Text("How it works")
                        .font(.headline)
                        .foregroundStyle(SettingsTheme.secondaryText)
                    HyperKeyInstructions()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .groupedCard()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        shortcutDescription
                        Spacer(minLength: 0)
                        shortcutButton
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        shortcutDescription
                        shortcutButton
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private var shortcutDescription: some View {
        Text("Assign Hyper combos to Tooki features and apps.")
            .font(.callout)
            .foregroundStyle(SettingsTheme.secondaryText)
    }

    private var shortcutButton: some View {
        Button("Open Shortcuts", systemImage: "arrow.right", action: onOpenShortcuts)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}
