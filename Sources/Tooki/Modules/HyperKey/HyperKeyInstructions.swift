import SwiftUI

struct HyperKeyInstructions: View {
    var body: some View {
        instruction("Hold Caps Lock", symbol: "hand.raised", detail:
            "It acts as Control + Option + Shift + Command (⌃⌥⇧⌘), giving your shortcuts their own modifier.")
        instruction("Tap Caps Lock", symbol: "capslock", detail:
            "A quick tap still turns Caps Lock on or off.")
        instruction("Works in every app", symbol: "app.connected.to.app.below.fill", detail:
            "Other apps see ⌃⌥⇧⌘, so you can use Hyper in their shortcuts too.")
    }

    private func instruction(_ title: String, symbol: String, detail: String) -> some View {
        SettingsCardRow {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(SettingsTheme.secondaryText)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                SettingsRowLabel(title: title, description: detail)
            }
        }
    }
}
