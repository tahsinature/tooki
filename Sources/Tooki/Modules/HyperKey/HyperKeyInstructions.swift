import SwiftUI

struct HyperKeyInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            instruction("Hold Caps Lock", symbol: "hand.raised", detail:
                "It acts as Control + Option + Shift + Command (⌃⌥⇧⌘), giving your shortcuts their own modifier.")
            instruction("Tap Caps Lock", symbol: "capslock", detail:
                "A quick tap still turns Caps Lock on or off.")
            instruction("Works in every app", symbol: "app.connected.to.app.below.fill", detail:
                "Other apps see ⌃⌥⇧⌘, so you can use Hyper in their shortcuts too.")
        }
    }

    private func instruction(_ title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(SettingsTheme.accent)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
