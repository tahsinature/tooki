import SwiftUI

/// The right column for a shelf: its first few items and a summary.
struct ShelfManagerShelfDetail: View {
    let shelf: Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(shelf.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PanelTheme.primaryText)
                HStack(spacing: 8) {
                    ForEach(shelf.items.prefix(4)) { item in
                        VStack(spacing: 6) {
                            ShelfItemIcon(item: item, size: 36)
                            Text(item.name)
                                .font(.system(size: 10))
                                .foregroundStyle(PanelTheme.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(width: 84, height: 84)
                        .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(16)
            Spacer(minLength: 0)
            MetadataList(title: "Information", items: [
                MetadataItem(label: "Items", value: shelf.items.count.formatted()),
                MetadataItem(label: "Size", value: shelf.totalBytes > 0 ? shelf.totalBytes.formatted(.byteCount(style: .file)) : nil),
                MetadataItem(label: "Copies", value: shelf.items.filter(\.isCopy).count.formatted()),
                MetadataItem(label: "Last Used", value: shelf.lastUsed.formatted(.relative(presentation: .named)),
                             help: shelf.lastUsed.formatted(date: .abbreviated, time: .shortened)),
            ])
        }
    }
}

/// The right column for an item: a preview, then where it is and where it came from.
struct ShelfManagerItemDetail: View {
    let item: ShelfItem
    let shelf: Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShelfItemIcon(item: item, size: 128)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 8))
                .padding(16)
            MetadataList(title: "Information", items: [
                MetadataItem(label: "Kind", value: kind),
                MetadataItem(label: "Size", value: item.detail),
                MetadataItem(label: "Shelf", value: shelf.name),
                MetadataItem(label: "Original", value: item.isCopy ? item.displayOriginalPath : nil),
                MetadataItem(label: "Path", value: item.displayPath),
            ])
        }
    }

    private var kind: String {
        if item.isLink { return "Saved link" }
        if item.originalPath != nil { return "Copy. The original never moves" }
        if item.ownsFile { return "Saved by Tooki" }
        return "Original. Dragging it out can move it"
    }
}
