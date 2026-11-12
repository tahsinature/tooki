import SwiftUI
import TookiKit

/// The footer's Drag button: drag the item into another app, for places that can't paste.
struct ClipboardDragButton: View {
    let item: ClipboardItem
    /// Runs after a successful drop, not when the drag is cancelled.
    let onDropped: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @ViewState private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw")
                .font(.system(size: 14))
            Text("Drag")
                .font(PanelTheme.labelFont)
        }
        .foregroundStyle(isEnabled && isHovered ? PanelTheme.primaryText : PanelTheme.secondaryText)
        .opacity(isEnabled ? 1 : 0.5)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(isEnabled && isHovered ? PanelTheme.hoverBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            ClipboardDragSource(item: item, isEnabled: isEnabled, isHovered: $isHovered, onDropped: onDropped)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Drag")
        .accessibilityHint("Drag this item into another app")
    }
}
