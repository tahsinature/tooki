import SwiftUI
import TookiDesignSystem
@testable import Tooki

/// Exercises selected and normal compact rows without opening a real Shelf window.
struct FloatingShelfFixture: View {
    let shelf: Shelf
    @Namespace private var namespace

    var body: some View {
        ShelfRows(shelf: shelf, namespace: namespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PanelTheme.barBackground)
    }
}
