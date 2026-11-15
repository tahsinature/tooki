import SwiftUI

/// A quiet label above a group of rows, like "Pinned" or "Today".
public struct SectionHeader: View {
    let title: String
    var isFirst = false

    public init(title: String, isFirst: Bool = false) {
        self.title = title
        self.isFirst = isFirst
    }

    nonisolated public static func height(isFirst: Bool) -> CGFloat {
        isFirst ? PanelTheme.firstSectionHeight : PanelTheme.sectionHeight
    }

    public var body: some View {
        HStack(spacing: PanelTheme.sectionSpacing) {
            Text(title)
                .font(PanelTheme.sectionFont)
                .foregroundStyle(PanelTheme.secondaryText)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle()
                .fill(PanelTheme.separator)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PanelTheme.rowHorizontalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height(isFirst: isFirst))
        .accessibilityAddTraits(.isHeader)
    }
}
