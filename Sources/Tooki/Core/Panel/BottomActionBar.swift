import SwiftUI

/// The bar along the bottom of a panel: what is open on the left; the main action and "Actions ⌘K" on the right.
struct BottomActionBar: View {
    let title: String
    let icon: PanelIcon
    /// `nil` hides the main action, e.g. when nothing is selected.
    let primaryActionTitle: String?
    var primaryShortcut = "↵"
    let onPrimaryAction: () -> Void
    /// A second action shown before the main one, e.g. "Create Snippet ⌘N".
    var secondaryAction: FooterAction?
    /// `nil` hides "Actions ⌘K", e.g. in a form.
    let onShowActions: (() -> Void)?
    /// Makes the icon and title on the left a button, e.g. to open Settings from search.
    var badgeAction: FooterAction?
    /// An optional control immediately before the primary action, such as Clipboard History's Drag button.
    var accessory: AnyView?
    /// Search shares one surface across its results and actions.
    var blendsWithPanel = false

    var body: some View {
        HStack(spacing: 8) {
            if let badgeAction {
                Button(action: badgeAction.run) { badge }
                    .buttonStyle(InteractionButtonStyle(horizontalPadding: 8, verticalPadding: 4))
                    .help("\(badgeAction.title) (\(badgeAction.shortcut))")
            } else {
                badge
            }
            Spacer(minLength: 12)
            if let secondaryAction {
                BarButton(title: secondaryAction.title, shortcut: secondaryAction.shortcut, isPrimary: false, action: secondaryAction.run)
                if primaryActionTitle != nil || onShowActions != nil { separator }
            }
            if let accessory { accessory }
            if let primaryActionTitle {
                BarButton(title: primaryActionTitle, shortcut: primaryShortcut, isPrimary: true, action: onPrimaryAction)
            }
            if primaryActionTitle != nil, onShowActions != nil { separator }
            if let onShowActions {
                BarButton(title: "Actions", shortcut: "⌘K", isPrimary: false, action: onShowActions)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: PanelTheme.footerHeight)
        .background(blendsWithPanel ? Color.primary.opacity(0.025) : PanelTheme.barBackground)
        .overlay(alignment: .top) {
            if blendsWithPanel { Rectangle().fill(PanelTheme.popupDivider).frame(height: 0.5) }
        }
    }

    private var separator: some View {
        Capsule()
            .fill(PanelTheme.separator)
            .frame(width: 2, height: 11)
            .padding(.horizontal, 4)
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

/// A footer button with its shortcut. The panel handles the shortcut key itself.
struct FooterAction {
    let title: String
    let shortcut: String
    let run: () -> Void
}

private struct BarButton: View {
    let title: String
    let shortcut: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(PanelTheme.labelFont)
                    .foregroundStyle(isPrimary ? PanelTheme.primaryText : PanelTheme.secondaryText)
                Keycap(shortcut: shortcut)
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractionButtonStyle())
    }
}
