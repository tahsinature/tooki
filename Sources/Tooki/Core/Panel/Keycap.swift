import SwiftUI

/// Outlined key caps for a shortcut, one cap per key: "⌘K" shows ⌘ and K.
struct Keycap: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(shortcut.enumerated()), id: \.offset) { _, key in
                Text(String(key))
                    .font(PanelTheme.keycapFont)
                    .foregroundStyle(PanelTheme.secondaryText)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 18, minHeight: 18)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(PanelTheme.keycapBorder))
            }
        }
    }
}
