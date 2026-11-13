import SwiftUI

/// The same label/value layout as other settings rows, with one copy target and indicator.
struct SnippetPlaceholderRow: View {
    let placeholder: SnippetPlaceholder

    var body: some View {
        CopyButton(text: placeholder.token, label: placeholder.title) {
            SettingsRow(placeholder.title, description: placeholder.detail) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(placeholder.token)
                        .font(SettingsTheme.controlFont.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(placeholder.token)
                    if let example = placeholder.example {
                        Text(example)
                            .font(SettingsTheme.rowDescriptionFont)
                            .foregroundStyle(SettingsTheme.secondaryText)
                            .lineLimit(1)
                            .help(example)
                    }
                }
                .frame(maxWidth: 240, alignment: .trailing)
            }
        }
    }
}
