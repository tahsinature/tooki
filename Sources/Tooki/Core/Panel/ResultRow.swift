import SwiftUI

/// One row of a panel list: icon, title, optional subtitle, and a trailing accessory.
struct ResultRow<Leading: View, Trailing: View>: View {
    @Environment(\.compactPanelLayout) private var isCompact
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var isDimmed = false
    var titleColor: Color = PanelTheme.primaryText
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    @ViewState private var isHovered = false

    var body: some View {
        HStack(spacing: isCompact ? 10 : PanelTheme.rowSpacing) {
            leading
                .opacity(isDimmed ? 0.4 : 1)
            Text(title)
                .font(isCompact ? .system(size: 12, weight: .medium) : PanelTheme.rowTitleFont)
                .foregroundStyle(isDimmed ? PanelTheme.secondaryText : titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
            if let subtitle {
                Text(subtitle)
                    .font(PanelTheme.rowTitleFont)
                    .foregroundStyle(PanelTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            trailing
            if isSelected && isCompact {
                Capsule()
                    .fill(PanelTheme.selectionIndicator)
                    .frame(width: 3, height: 14)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: isCompact ? 34 : PanelTheme.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: radius)
                    .fill(PanelTheme.selectedBackground)
                    .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(PanelTheme.selectedRim))
            } else if isHovered {
                RoundedRectangle(cornerRadius: radius)
                    .fill(PanelTheme.hoverBackground)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var radius: CGFloat { isCompact ? 6 : PanelTheme.rowRadius }
}

/// A quiet label above a group of rows, like "Pinned" or "Today".
/// The launcher uses Asyar's smaller root-list style; split lists use the bolder one.
struct SectionHeader: View {
    let title: String
    var isFirst = false
    var isCompact = false

    var body: some View {
        Text(title)
            .font(.system(size: isCompact ? 12 : 13, weight: isCompact ? .medium : .semibold))
            .foregroundStyle(PanelTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.top, isFirst ? (isCompact ? 0 : 4) : (isCompact ? 10 : 16))
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
