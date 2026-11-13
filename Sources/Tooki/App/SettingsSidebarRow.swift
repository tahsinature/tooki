import SwiftUI

struct SettingsSidebarRow: View {
    let page: SettingsPage
    let isSelected: Bool
    var hasWarning = false
    var hasUpdate = false
    let select: () -> Void
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 19, height: 19)
                    .background(page.tileColor.gradient, in: RoundedRectangle(cornerRadius: 5))
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(SettingsTheme.font(11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? SettingsTheme.primaryText : SettingsTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if hasWarning {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.yellow)
                        .font(.system(size: 10)).help("Some settings need your attention")
                }
                if hasUpdate {
                    Circle().fill(.blue).frame(width: 6, height: 6).help("An update is available")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(isSelected ? SettingsTheme.sidebarSelection : isHovered ? Color.primary.opacity(0.035) : .clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(hasUpdate ? "Update available" : hasWarning ? "Needs attention" : "")
    }
}
