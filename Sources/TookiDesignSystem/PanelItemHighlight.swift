import SwiftUI

/// Shared hover and keyboard-selection feedback for panel rows and grid cells.
private struct PanelItemHighlight: ViewModifier {
    let isSelected: Bool
    @ViewState private var isHovered = false

    func body(content: Content) -> some View {
        content
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

extension View {
    public func panelItemHighlight(isSelected: Bool) -> some View {
        modifier(PanelItemHighlight(isSelected: isSelected))
    }
}
