import SwiftUI

/// Shared frame for tool panels. Tools supply their header, content and footer;
/// the layout owns the surface, size and placement so they stay consistent.
struct PanelLayout<Header: View, Content: View, Footer: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: PanelTheme.headerHeight)
                .background(alignment: .bottom) {
                    PanelTheme.separator.frame(height: 1)
                }
                // Filter menus extend from the header over the content.
                .zIndex(1)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(width: PanelTheme.size.width, height: PanelTheme.size.height)
        .panelSurface()
    }
}
