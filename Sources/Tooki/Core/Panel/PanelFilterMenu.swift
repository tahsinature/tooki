import SwiftUI

/// A filter button at the end of a panel's search field, like "All Types" or "All Collections",
/// with a ⌘P hint on hover. Clicking it, or setting `isOpen`, shows a `FilterPopup` below it.
/// `nil` selects everything.
struct PanelFilterMenu<Value: Hashable>: View {
    @Binding var selection: Value?
    @Binding var isOpen: Bool
    let allTitle: String
    let filterTitle: String
    let options: [(value: Value, title: String)]

    @ViewState private var isHovered = false
    @ViewState private var isHintVisible = false

    private static var buttonHeight: CGFloat { 26 }

    var body: some View {
        button
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
                } else if isHintVisible && isHovered {
                    FilterMenuHint(title: filterTitle)
                        .offset(y: Self.buttonHeight + 8)
                }
            }
            .task(id: isHovered && !isOpen) {
                isHintVisible = false
                guard isHovered && !isOpen else { return }
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                isHintVisible = true
            }
    }

    private var button: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                Text(selectedTitle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(PanelTheme.labelFont)
            .foregroundStyle(isHovered || isOpen ? PanelTheme.primaryText : PanelTheme.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: Self.buttonHeight)
            .background(isHovered || isOpen ? PanelTheme.hoverBackground : PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: PanelTheme.rowRadius))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(filterTitle)
        .accessibilityValue(selectedTitle)
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
