import SwiftUI

/// A quiet label above a group of rows, like "Pinned" or "Today".
struct SectionHeader: View {
    let title: String
    var isFirst = false

    nonisolated static func height(isFirst: Bool) -> CGFloat {
        isFirst ? 24 : 32
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PanelTheme.secondaryText)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle()
                .fill(PanelTheme.separator)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height(isFirst: isFirst))
        .accessibilityAddTraits(.isHeader)
    }
}
