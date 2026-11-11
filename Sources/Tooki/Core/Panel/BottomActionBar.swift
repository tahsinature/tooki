import SwiftUI

/// The bar along the bottom of a panel: what is open on the left; the main action and "Actions ⌘K" on the right.
struct BottomActionBar: View {
    let title: String
    let icon: PanelIcon
    /// `nil` hides the main action, e.g. when nothing is selected.
    let primaryActionTitle: String?
    var primaryShortcut = "↵"
    let onPrimaryAction: () -> Void
    /// `nil` hides "Actions ⌘K", e.g. in a form.
    let onShowActions: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            badge
            Spacer(minLength: 12)
            if let primaryActionTitle {
                BarButton(title: primaryActionTitle, shortcut: primaryShortcut, isPrimary: true, action: onPrimaryAction)
            }
            if primaryActionTitle != nil, onShowActions != nil {
                Capsule()
                    .fill(PanelTheme.separator)
                    .frame(width: 2, height: 11)
                    .padding(.horizontal, 4)
            }
            if let onShowActions {
                BarButton(title: "Actions", shortcut: "⌘K", isPrimary: false, action: onShowActions)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: PanelTheme.footerHeight)
        .background(PanelTheme.barBackground)
    }

    private var badge: some View {
        HStack(spacing: 6) {
            PanelIconView(icon: icon, size: 20)
                .foregroundStyle(.white)
                .background(PanelTheme.accentFill, in: RoundedRectangle(cornerRadius: 6))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PanelTheme.primaryText)
                .lineLimit(1)
        }
    }
}

private struct BarButton: View {
    let title: String
    let shortcut: String
    let isPrimary: Bool
    let action: () -> Void

    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(PanelTheme.labelFont)
                    .foregroundStyle(isPrimary || isHovered ? PanelTheme.primaryText : PanelTheme.secondaryText)
                Keycap(shortcut: shortcut)
            }
            .padding(4)
            .background(isHovered ? PanelTheme.hoverBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
