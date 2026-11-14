import SwiftUI

/// One row of a panel list: icon, title, optional subtitle, and a trailing accessory.
struct ResultRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var isDimmed = false
    var titleColor: Color = PanelTheme.primaryText
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    @ViewState private var isHovered = false

    var body: some View {
        HStack(spacing: PanelTheme.rowSpacing) {
            leading
                .frame(width: PanelTheme.rowIconSize, height: PanelTheme.rowIconSize)
                .opacity(isDimmed ? 0.4 : 1)
            Text(title)
                .font(PanelTheme.rowTitleFont)
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
        }
        .padding(.horizontal, 8)
        .frame(minHeight: PanelTheme.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: PanelTheme.rowRadius)
                    .fill(PanelTheme.selectedBackground)
                    .overlay(RoundedRectangle(cornerRadius: PanelTheme.rowRadius).strokeBorder(PanelTheme.selectedRim))
            } else if isHovered {
                RoundedRectangle(cornerRadius: PanelTheme.rowRadius)
                    .fill(PanelTheme.hoverBackground)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
