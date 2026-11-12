import SwiftUI

/// The left column: every shelf, or the items of the open shelf.
struct ShelfManagerList: View {
    let model: ShelfManagerModel
    let onDoubleClick: () -> Void

    var body: some View {
        if let shelf = model.openShelf {
            GroupedPanelList(
                sections: [PanelListSection(title: shelf.name, items: model.items)],
                selectedID: model.selectedItem?.id,
                onSelect: { model.selectedItemID = $0 },
                onDoubleClick: onDoubleClick,
                onShowActions: model.actions.open,
                row: itemRow
            )
        } else {
            GroupedPanelList(
                sections: [PanelListSection(title: "Shelves", items: model.shelves)],
                selectedID: model.selectedShelf?.id,
                onSelect: { model.selectedShelfID = $0 },
                onDoubleClick: onDoubleClick,
                onShowActions: model.actions.open,
                row: shelfRow
            )
        }
    }

    private func shelfRow(_ shelf: Shelf, isSelected: Bool) -> some View {
        ResultRow(title: shelf.name, isSelected: isSelected) {
            Image(systemName: "tray.full")
                .font(.system(size: 14))
                .foregroundStyle(PanelTheme.secondaryText)
        } trailing: {
            Text(ShelfText.itemCount(shelf.items.count).lowercased())
                .font(.system(size: 11))
                .foregroundStyle(PanelTheme.tertiaryText)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PanelTheme.tertiaryText)
        }
    }

    private func itemRow(_ item: ShelfItem, isSelected: Bool) -> some View {
        ResultRow(title: item.name, isSelected: isSelected) {
            ShelfItemIcon(item: item, size: 20)
        } trailing: {
            Text(item.shortDetail)
                .font(.system(size: 11))
                .foregroundStyle(PanelTheme.tertiaryText)
        }
        // Drags the file itself into other apps, like dragging it off the shelf.
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
    }
}
