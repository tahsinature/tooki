import SwiftUI

/// The Filter Menu's hover hint, shown below the button to stay inside the panel.
struct FilterMenuHint: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(PanelTheme.labelFont)
                .foregroundStyle(PanelTheme.primaryText)
            HStack(spacing: 3) {
                Keycap(shortcut: "⌘")
                Keycap(shortcut: "P")
            }
        }
        .padding(8)
        .fixedSize()
        .popupSurface(cornerRadius: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
