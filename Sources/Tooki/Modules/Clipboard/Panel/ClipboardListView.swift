import SwiftUI
import TookiKit

/// The left column: a Pinned section and a Most Recent section.
struct ClipboardListView: View {
    let model: ClipboardPanelModel
    let onCopy: () -> Void

    var body: some View {
        let selectedID = model.selectedItem?.id
        ScrollViewReader { proxy in
            ScrollView {
                // One ForEach for both sections, so pinning moves a row instead of leaving a stale copy behind.
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        // Keep one layout container per entry, including section headers.
                        // Explicit heights keep lazy scroll measurements stable as entries unload.
                        VStack(alignment: .leading, spacing: 0) {
                            switch entry {
                            case .header(let title):
                                header(title)
                            case .item(let item):
                                row(item, isSelected: item.id == selectedID)
                            }
                        }
                        .frame(height: entry.height)
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            // Margins, not padding, so scrolling to the last row keeps space below it.
            .contentMargins(.top, 8, for: .scrollContent)
            .contentMargins(.bottom, 12, for: .scrollContent)
            .onChange(of: selectedID) { _, newValue in
                if let newValue { proxy.scrollTo(ListEntry.itemID(newValue)) }
            }
        }
    }

    private var entries: [ListEntry] {
        section("Pinned", model.pinned) + section("Most Recent", model.recent)
    }

    private func section(_ title: String, _ items: [ClipboardItem]) -> [ListEntry] {
        items.isEmpty ? [] : [.header(title)] + items.map(ListEntry.item)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func row(_ item: ClipboardItem, isSelected: Bool) -> some View {
        ClipboardRow(item: item, isSelected: isSelected)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onCopy)
            .simultaneousGesture(TapGesture().onEnded { model.selectedID = item.id })
    }
}

private enum ListEntry: Identifiable {
    case header(String)
    case item(ClipboardItem)

    static func itemID(_ id: ClipboardItem.ID) -> String { id.uuidString }

    var height: CGFloat {
        switch self {
        case .header: 24
        case .item: 34
        }
    }

    var id: String {
        switch self {
        case .header(let title): "header-\(title)"
        case .item(let item): Self.itemID(item.id)
        }
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        let isMissing = !item.canBeUsed
        HStack(spacing: 10) {
            ClipboardIcon(item: item, size: 18)
                .opacity(isMissing ? 0.4 : 1)
            Text(item.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isMissing ? .secondary : .primary)
            Spacer(minLength: 0)
            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("The file no longer exists")
            }
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
