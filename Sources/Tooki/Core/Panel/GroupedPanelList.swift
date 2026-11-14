import SwiftUI
import TookiKit

/// A titled group of rows in a `GroupedPanelList`, like "Pinned" or "Today".
struct PanelListSection<Item: Identifiable> {
    let title: String?
    let items: [Item]

    /// Groups items by day (Today, Yesterday, This Week…), skipping empty days. Keeps the items' order.
    static func byDay(_ items: [Item], date: (Item) -> Date, now: Date = Date()) -> [PanelListSection] {
        let grouped = Dictionary(grouping: items) { TimeSection(of: date($0), now: now) }
        return TimeSection.allCases.compactMap { section in
            grouped[section].map { PanelListSection(title: section.rawValue, items: $0) }
        }
    }
}

/// The left column of a list-and-detail panel: section headers and selectable rows.
/// Keeps the selected row scrolled into view.
struct GroupedPanelList<Item: Identifiable, Row: View>: View {
    let sections: [PanelListSection<Item>]
    let selectedID: Item.ID?
    let onSelect: (Item.ID) -> Void
    let onDoubleClick: () -> Void
    let onShowActions: () -> Void
    @ViewBuilder let row: (_ item: Item, _ isSelected: Bool) -> Row

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // One ForEach for every section, so moving an item between sections moves its row
                // instead of leaving a stale copy behind.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        // Explicit heights keep lazy scroll measurements stable as entries unload.
                        VStack(alignment: .leading, spacing: 0) {
                            switch entry.kind {
                            case .header(let title, let isFirst):
                                SectionHeader(title: title, isFirst: isFirst)
                            case .item(let item):
                                row(item, item.id == selectedID)
                                    .onTapGesture(count: 2, perform: onDoubleClick)
                                    .simultaneousGesture(TapGesture().onEnded { onSelect(item.id) })
                                    .overlay {
                                        SecondaryClickArea {
                                            onSelect(item.id)
                                            onShowActions()
                                        }
                                    }
                            }
                        }
                        .frame(height: entry.height)
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, PanelTheme.listInset)
                .panelScrollContent()
            }
            // Margins, not padding, so scrolling to the last row keeps space below it.
            .contentMargins(.vertical, PanelTheme.listInset, for: .scrollContent)
            .panelSelectionScrolling(
                proxy: proxy,
                selection: selectedID.map { Entry.itemID($0) },
                first: sections.first(where: { !$0.items.isEmpty })?.items.first.map { Entry.itemID($0.id) },
                last: sections.last(where: { !$0.items.isEmpty })?.items.last.map { Entry.itemID($0.id) }
            )
        }
    }

    private var entries: [Entry] {
        var entries: [Entry] = []
        for section in sections where !section.items.isEmpty {
            if let title = section.title {
                entries.append(Entry(kind: .header(title, isFirst: entries.isEmpty)))
            }
            entries += section.items.map { Entry(kind: .item($0)) }
        }
        return entries
    }

    private struct Entry: Identifiable {
        enum Kind {
            case header(String, isFirst: Bool)
            case item(Item)
        }

        let kind: Kind

        static func itemID(_ id: Item.ID) -> String { "item-\(id)" }

        var id: String {
            switch kind {
            case .header(let title, _): "header-\(title)"
            case .item(let item): Self.itemID(item.id)
            }
        }

        var height: CGFloat {
            switch kind {
            case .header(_, let isFirst): SectionHeader.height(isFirst: isFirst)
            case .item: PanelTheme.rowHeight
            }
        }
    }
}
