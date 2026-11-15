import SwiftUI

/// One row of a panel list: icon, title, optional subtitle, and a trailing accessory.
public struct ResultRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var isDimmed = false
    var titleColor: Color = PanelTheme.primaryText
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing


    public init(title: String, subtitle: String? = nil, isSelected: Bool, isDimmed: Bool = false,
                titleColor: Color = PanelTheme.primaryText,
                @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isDimmed = isDimmed
        self.titleColor = titleColor
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
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
        .padding(.horizontal, PanelTheme.rowHorizontalInset)
        .frame(minHeight: PanelTheme.rowHeight)
        .panelItemHighlight(isSelected: isSelected)
    }
}
