import SwiftUI

/// Reuses the shelf converter while the manager's list and bottom actions stay in place.
struct ShelfManagerConversionDetail: View {
    let model: ShelfManagerModel
    let shelf: Shelf

    private var width: CGFloat { PanelTheme.listDetailSize.width - PanelTheme.listWidth - 1 }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                SlidingPagesLayout(page: model.isShowingConversion ? 1 : 0, width: width) {
                    Group {
                        if let item = model.selectedItem { ShelfManagerItemDetail(item: item, shelf: shelf) }
                    }
                    .frame(height: geometry.size.height)
                    .accessibilityHidden(model.isShowingConversion)
                    if let conversion = model.imageConversion {
                        ShelfImageConversionView(model: conversion, width: width, showsFooterActions: false)
                            .accessibilityHidden(!model.isShowingConversion)
                    }
                }
                .animation(.easeInOut(duration: ShelfMotion.duration), value: model.isShowingConversion)
            }
        }
        .frame(width: width)
        .clipped()
    }
}
