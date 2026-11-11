import SwiftUI

/// A filter button at the end of a panel's search field, like "All Types" or "All Collections",
/// with a ⌘P hint. Clicking it, or setting `isOpen`, shows a `FilterPopup` below it.
/// `nil` selects everything.
struct PanelFilterMenu<Value: Hashable>: View {
    @Binding var selection: Value?
    @Binding var isOpen: Bool
    let allTitle: String
    let options: [(value: Value, title: String)]

    @ViewState private var isHovered = false

    private static var buttonHeight: CGFloat { 26 }

    var body: some View {
        HStack(spacing: 8) {
            button
            Keycap(shortcut: "⌘P")
        }
        .fixedSize()
        .overlay(alignment: .topTrailing) {
            if isOpen {
                FilterPopup(
                    titles: [allTitle] + options.map(\.title),
                    current: options.firstIndex { $0.value == selection }.map { $0 + 1 } ?? 0,
                    onPick: pick,
                    onClose: { isOpen = false }
                )
                .fixedSize()
                .offset(y: Self.buttonHeight + 8)
            }
        }
    }

    private var button: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Text(selectedTitle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(PanelTheme.labelFont)
            .foregroundStyle(isHovered || isOpen ? PanelTheme.primaryText : PanelTheme.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: Self.buttonHeight)
            .background(isHovered || isOpen ? PanelTheme.hoverBackground : PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var selectedTitle: String {
        options.first { $0.value == selection }?.title ?? allTitle
    }

    /// Index 0 is "All"; the rest follow `options`.
    private func pick(_ index: Int) {
        selection = index == 0 ? nil : options[index - 1].value
        isOpen = false
    }
}
