import SwiftUI

/// Monospaced text with the same copy feedback as other copyable rows.
struct CopyableText: View {
    let text: String
    let label: String

    var body: some View {
        CopyButton(text: text, label: label) {
            Text(label)
                .font(SettingsTheme.controlFont.monospaced())
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}
