import SwiftUI

/// The panel's command line: a large search field with an optional accessory (a filter menu) at the end.
/// The leading glyph has the row icon's width, so typed text lines up with the row titles below.
struct SearchHeader<Accessory: View>: View {
    @Environment(\.compactPanelLayout) private var isCompact
    let placeholder: String
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    let onKey: (KeyPress) -> KeyPress.Result
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: isCompact ? 10 : PanelTheme.rowSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PanelTheme.secondaryText)
                .frame(width: PanelTheme.rowIconSize, height: PanelTheme.rowIconSize)
            TextField(
                "",
                text: $query,
                prompt: Text(placeholder).foregroundStyle(PanelTheme.tertiaryText)
            )
            .textFieldStyle(.plain)
            .font(isCompact ? .system(size: 16, weight: .medium) : PanelTheme.queryFont)
            .tracking(PanelTheme.queryTracking)
            .foregroundStyle(PanelTheme.primaryText)
            .tint(PanelTheme.accent)
            .focused(isFocused)
            .onKeyPress(phases: [.down, .repeat], action: onKey)
            accessory
        }
        .padding(.horizontal, 16)
        .frame(height: isCompact ? 46 : PanelTheme.headerHeight)
        // Keep the separator behind the Filter Menu when its popup overlaps the header.
        .background(alignment: .bottom) {
            PanelTheme.separator.frame(height: 1)
        }
    }
}
