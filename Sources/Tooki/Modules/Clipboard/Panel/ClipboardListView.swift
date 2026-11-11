import SwiftUI
import TookiKit

/// The left column: pinned items, then the rest grouped by day (Today, Yesterday, This Week…).
struct ClipboardListView: View {
    let model: ClipboardPanelModel
    let onCopy: () -> Void

    var body: some View {
        GroupedPanelList(
            sections: [PanelListSection(title: "Pinned", items: model.pinned)]
                + PanelListSection.byDay(model.recent, date: \.copiedAt),
            selectedID: model.selectedItem?.id,
            onSelect: { model.selectedID = $0 },
            onDoubleClick: onCopy,
            row: row
        )
    }

    private func row(_ item: ClipboardItem, isSelected: Bool) -> some View {
        let isMissing = !item.canBeUsed
        return ResultRow(title: item.title, isSelected: isSelected, isDimmed: isMissing) {
            ClipboardIcon(item: item, size: 20)
                .foregroundStyle(PanelTheme.secondaryText)
        } trailing: {
            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help("The file no longer exists")
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.secondaryText)
            }
        }
    }
}
