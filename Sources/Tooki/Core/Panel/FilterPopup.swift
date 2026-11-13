import SwiftUI

/// The popup under a `PanelFilterMenu`: a search field on top and the options below,
/// with a checkmark on the current one. ↑↓ move, ↵ picks, Esc or ⌘P closes.
struct FilterPopup: View {
    /// The first title is the "All" option.
    let titles: [String]
    let current: Int
    let onPick: (_ index: Int) -> Void
    let onClose: () -> Void

    @ViewState private var query = ""
    @ViewState private var highlighted = 0
    @ViewState private var hoveredIndex: Int?
    @ViewState private var rowsHeight: CGFloat = 0
    @FocusState private var isQueryFocused: Bool

    static var width: CGFloat { 190 }
    private static var rowHeight: CGFloat { 26 }
    private static var listPadding: CGFloat { 5 }
    /// Room for eight rows and the divider before the list scrolls.
    private static var maxListHeight: CGFloat { 8 * rowHeight + 9 + 2 * listPadding }

    /// Indexes into `titles` that match the query.
    private var visible: [Int] {
        let words = query.lowercased().split(separator: " ")
        return titles.indices.filter { index in words.allSatisfy { titles[index].lowercased().contains($0) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Lines up with the rows: the icon over the checkmarks, the text over the titles.
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PanelTheme.tertiaryText)
                    .frame(width: 11)
                TextField("", text: $query.ignoringUnchangedValues(), prompt: Text("Search…").foregroundStyle(PanelTheme.tertiaryText))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(PanelTheme.primaryText)
                    .tint(PanelTheme.accent)
                    .focusOnPresentation($isQueryFocused)
                    .onKeyPress(phases: [.down, .repeat], action: handleKey)
            }
            .padding(.horizontal, Self.listPadding + 7)
            .frame(height: 36)
            PanelTheme.popupDivider.frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    rows.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(rowsHeight, Self.maxListHeight))
                .onChange(of: highlighted, initial: true) { proxy.scrollTo(highlighted) }
            }
        }
        .frame(width: Self.width)
        .popupSurface(cornerRadius: 10)
        .onAppear {
            highlighted = visible.firstIndex(of: current) ?? 0
        }
        .onChange(of: query) {
            highlighted = 0
            hoveredIndex = nil
        }
        // Clicking anywhere else in the panel closes it.
        .onChange(of: isQueryFocused) { _, isFocused in
            if !isFocused { onClose() }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visible.isEmpty {
                Text("No matches")
                    .font(.system(size: 12))
                    .foregroundStyle(PanelTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight)
            }
            ForEach(Array(visible.enumerated()), id: \.element) { position, index in
                row(index, isHighlighted: position == highlighted)
                    .onTapGesture { onPick(index) }
                    .id(position)
                // Separates "All" from the specific options, like in a menu.
                if index == 0, visible.count > 1 {
                    PanelTheme.popupDivider.frame(height: 1).padding(.vertical, 4)
                }
            }
        }
        .padding(Self.listPadding)
    }

    private func row(_ index: Int, isHighlighted: Bool) -> some View {
        let isCurrent = index == current
        return HStack(spacing: 7) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 11)
                .opacity(isCurrent ? 1 : 0)
            Text(titles[index])
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isCurrent ? PanelTheme.accent : PanelTheme.primaryText)
        .padding(.horizontal, 7)
        .frame(height: Self.rowHeight)
        .background(
            isHighlighted ? PanelTheme.selectedBackground : (hoveredIndex == index ? PanelTheme.hoverBackground : .clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            if isHovered {
                hoveredIndex = index
            } else if hoveredIndex == index {
                hoveredIndex = nil
            }
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            highlighted = max(highlighted - 1, 0)
        case .downArrow:
            highlighted = min(highlighted + 1, max(visible.count - 1, 0))
        case .return where press.phase == .down:
            if visible.indices.contains(highlighted) { onPick(visible[highlighted]) }
        case .escape where press.phase == .down:
            onClose()
        default:
            guard press.phase == .down, press.modifiers.contains(.command), press.characters.lowercased() == "p" else {
                return .ignored
            }
            onClose()
        }
        return .handled
    }
}
