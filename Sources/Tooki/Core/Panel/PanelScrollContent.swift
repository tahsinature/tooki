import SwiftUI

enum PanelScrollArea { case results, actions }
private enum PanelScrollEdge { case top, bottom }

extension View {
    /// Edge targets include all headings and padding, rather than just the selectable rows.
    func panelScrollContent() -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0).id(PanelScrollEdge.top)
            self
            Color.clear.frame(height: 0).id(PanelScrollEdge.bottom)
        }
    }

    func panelSelectionScrolling<ID: Hashable>(
        proxy: ScrollViewProxy, selection: ID?, first: ID?, last: ID?,
        area: PanelScrollArea = .results, rowHeight: CGFloat = PanelTheme.rowHeight, columns: Int = 1
    ) -> some View {
        modifier(PanelSelectionScrollModifier(
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
            proxy.scrollTo(PanelScrollEdge.bottom, anchor: .bottom)
        } else {
            proxy.scrollTo(selection)
        }
    }
}
