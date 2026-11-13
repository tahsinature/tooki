import SwiftUI

/// Resolve actual rows (including ForEach and conditionals) using public SwiftUI APIs.
/// macOS 14 retains all controls in a simple grouped stack.
struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if #available(macOS 15, *) {
                Group(subviews: content) { rows in
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            row.padding(.horizontal, 12).padding(.vertical, 7)
                            if row.id != rows.last?.id {
                                Rectangle().fill(SettingsTheme.separator).frame(height: 1).padding(.horizontal, 12)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(.horizontal, 12).padding(.vertical, 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.cardBackground, in: RoundedRectangle(cornerRadius: SettingsTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: SettingsTheme.cardRadius).strokeBorder(SettingsTheme.cardBorder))
    }
}
