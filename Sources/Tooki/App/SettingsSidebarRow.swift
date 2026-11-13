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
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 23, height: 23)
                    .background(page.tileColor.gradient, in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
                Text(page.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? SettingsTheme.primaryText : SettingsTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if hasWarning {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.yellow)
                        .font(.system(size: 12)).help("Some settings need your attention")
                }
                if hasUpdate {
                    Circle().fill(.blue).frame(width: 6, height: 6).help("An update is available")
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 36)
            .background(isSelected ? SettingsTheme.sidebarSelection : isHovered ? Color.primary.opacity(0.035) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(hasUpdate ? "Update available" : hasWarning ? "Needs attention" : "")
    }
}
