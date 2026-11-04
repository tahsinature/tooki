import SwiftUI
import TookiKit

/// The left column: a Pinned section and a Most Recent section.
struct ClipboardListView: View {
    let model: ClipboardPanelModel
    let onPaste: () -> Void

    var body: some View {
        let selectedID = model.selectedItem?.id
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: []) {
                    section("Pinned", items: model.pinned, selectedID: selectedID)
                    section("Most Recent", items: model.recent, selectedID: selectedID)
                }
                .padding(8)
            }
            .onChange(of: selectedID) { _, newValue in
                proxy.scrollTo(newValue)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [ClipboardItem], selectedID: ClipboardItem.ID?) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 2)
            ForEach(items) { item in
                ClipboardRow(item: item, isSelected: item.id == selectedID)
                    .id(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onPaste)
                    .simultaneousGesture(TapGesture().onEnded { model.selectedID = item.id })
            }
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ClipboardIcon(item: item, size: 18)
            Text(item.title)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}
