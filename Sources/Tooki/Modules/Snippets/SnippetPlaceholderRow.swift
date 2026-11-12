import SwiftUI

/// The entire reference row copies its token; the example stays aligned beneath the token.
struct SnippetPlaceholderRow: View {
    let placeholder: SnippetPlaceholder

    var body: some View {
        CopyButton(text: placeholder.token, label: placeholder.title) {
            HStack(spacing: 20) {
                SettingsRowLabel(title: placeholder.title, description: placeholder.detail)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(placeholder.token)
                        .font(.body.monospaced())
                    if let example = placeholder.example {
                        Text(example)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.vertical, 3)
        }
    }
}
