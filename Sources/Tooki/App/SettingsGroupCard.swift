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
                            row.padding(.horizontal, 16).padding(.vertical, 13)
                            if row.id != rows.last?.id {
                                Rectangle().fill(SettingsTheme.separator).frame(height: 1).padding(.horizontal, 16)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 18) { content }.padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(SettingsTheme.cardBorder))
    }
}
