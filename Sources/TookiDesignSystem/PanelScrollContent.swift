import SwiftUI

public enum PanelScrollArea { case results, actions }
private enum PanelScrollEdge { case top }

extension View {
    /// The content itself provides a stable top target, including section headings.
    public func panelScrollContent() -> some View {
        id(PanelScrollEdge.top)
    }

    public func panelSelectionScrolling<ID: Hashable>(
        proxy: ScrollViewProxy, selection: ID?, first: ID?, last: ID?,
        area: PanelScrollArea = .results, rowHeight: CGFloat = PanelTheme.rowHeight, columns: Int = 1,
        verticalInset: CGFloat = PanelTheme.listInset
    ) -> some View {
        // Margins stay visible when a real row is aligned to the bottom edge.
        contentMargins(.vertical, verticalInset, for: .scrollContent)
            .modifier(PanelSelectionScrollModifier(
                proxy: proxy, selection: selection, first: first, last: last,
                area: area, rowHeight: rowHeight, columns: columns
            ))
    }
}

private struct PanelSelectionScrollModifier<ID: Hashable>: ViewModifier {
    let proxy: ScrollViewProxy
    let selection: ID?
    let first: ID?
    let last: ID?
    let area: PanelScrollArea
    let rowHeight: CGFloat
    let columns: Int
    @Environment(\.panelKeyboardNavigation) private var navigation

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Int.self) { [rowHeight, columns] geometry in
                max(1, Int(geometry.size.height / rowHeight)) * columns
            } action: { navigation?.setPageSize($0, in: area) }
            .onChange(of: selection, initial: true) { scroll() }
            .onChange(of: navigation?.revision(in: area)) { scroll() }
    }

    private func scroll() {
        guard let selection else { return }
        if selection == first {
            proxy.scrollTo(PanelScrollEdge.top, anchor: .top)
        } else if selection == last {
            // Target the row so lazy containers realize it, rather than an estimated content edge.
            proxy.scrollTo(selection, anchor: .bottom)
        } else {
            proxy.scrollTo(selection)
        }
    }
}
