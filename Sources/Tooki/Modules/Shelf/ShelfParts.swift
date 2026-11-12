import AppKit
import SwiftUI

/// The list's bottom bar: how many items (or how many are selected), their size, and Clear.
struct ShelfFooter: View {
    let shelf: Shelf
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
            }
            .padding(.leading, 12)
            .frame(maxHeight: .infinity)
            .shelfWindowDragArea()
            HStack(spacing: 6) {
                if let item = shelf.detailItem {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                        .disabled(shelf.copyingIDs.contains(item.id))
                }
                ShelfClearButton(shelf: shelf, onClear: onClear)
            }
            .controlSize(.small)
            .fixedSize()
            .padding(.trailing, 12)
        }
        .frame(height: 36)
    }

    private var summary: String {
        if !shelf.selection.isEmpty {
            return "\(shelf.selection.count) of \(shelf.items.count) selected"
        }
        return ShelfText.summary(of: shelf)
    }
}

/// The expanded shelf: every item in a list. Click to select (⌘ or ⇧ to select more), or use
/// ↑ and ↓, then drag the selection out. Double-click opens an item.
struct ShelfRows: View {
    let shelf: Shelf
    let namespace: Namespace.ID

    private static let rowHeight: CGFloat = 30
    private static let maxVisibleRows = 9
    private static let rowGap: CGFloat = 2
    private static let edgePadding: CGFloat = 6

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(spacing: Self.rowGap) {
                    ForEach(shelf.items) { item in
                        ShelfRow(item: item, isSelected: shelf.selection.contains(item.id), shelf: shelf, namespace: namespace)
                            .frame(height: Self.rowHeight)
                            .id(item.id)
                    }
                }
                .padding(Self.edgePadding)
            }
            .frame(height: listHeight)
            .onChange(of: shelf.cursor) { _, cursor in
                if let cursor { scroller.scrollTo(cursor) }
            }
        }
    }

    private var listHeight: CGFloat {
        let rows = CGFloat(min(shelf.items.count, Self.maxVisibleRows))
        return rows * Self.rowHeight + max(rows - 1, 0) * Self.rowGap + Self.edgePadding * 2
    }
}

/// One line per item: icon with its Original or Copy mark, name, and size.
/// Hovering swaps the size for an ⓘ that opens the item's details.
private struct ShelfRow: View {
    let item: ShelfItem
    let isSelected: Bool
    let shelf: Shelf
    let namespace: Namespace.ID

    @State private var isHovered = false

    private var isCopying: Bool { shelf.copyingIDs.contains(item.id) }

    var body: some View {
        HStack(spacing: 8) {
            ShelfItemIcon(item: item, size: 18)
                .matchedGeometryEffect(id: item.id, in: namespace)
                .overlay(alignment: .bottomTrailing) { ShelfKindBadge(isCopy: item.isCopy) }
            Text(item.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if isCopying {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .tint(.green)
                    .frame(width: 44)
                    .help("Copying…")
            } else {
                Text(item.shortDetail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                    .opacity(isHovered ? 0 : 1)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(
            isSelected ? Color.accentColor : (isHovered ? PanelTheme.hoverBackground : .clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            ShelfDragArea(
                items: { shelf.itemsToDrag(startingAt: item) },
                onClick: { event in
                    if event.clickCount == 2 {
                        NSWorkspace.shared.open(item.url)
                    } else {
                        shelf.click(item, modifiers: event.modifierFlags)
                    }
                },
                tooltip: item.tooltip,
                tooltipArea: ShelfKindBadge.area(inRowOf:),
                menu: { ShelfItemMenu.make(for: shelf.itemsForMenu(clickedOn: item), on: shelf) },
                onDropped: { shelf.didDragOut($0) }
            )
        )
        .overlay(alignment: .trailing) {
            if isHovered && !isCopying { infoButton }
        }
        .onHover { isHovered = $0 }
    }

    private var infoButton: some View {
        Button { shelf.showDetail(of: item) } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Details (→)")
        .padding(.trailing, 4)
    }
}

/// A small corner mark on the icon: an arrow for a link to the original, two pages for Tooki's copy.
private struct ShelfKindBadge: View {
    let isCopy: Bool

    var body: some View {
        Image(systemName: isCopy ? "doc.on.doc.fill" : "arrow.up.right")
            .font(.system(size: 5.5, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 10, height: 10)
            .background(isCopy ? Color.green : Color.orange, in: Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: 1))
            .offset(x: 3, y: 3)
    }

    /// Where the badge sits in a row: on the bottom right of the 18 pt icon, 8 pt in from the edge.
    /// A little larger than the badge, so it's easy to point at.
    static func area(inRowOf size: CGSize) -> CGRect {
        CGRect(x: 19, y: size.height / 2 + 2, width: 10, height: 10).insetBy(dx: -3, dy: -3)
    }
}

/// Clear, which turns red and asks "Clear?" when the shelf has copies.
/// Click again or press Return to clear; Esc, moving away or waiting lets it go.
struct ShelfClearButton: View {
    let shelf: Shelf
    let onClear: () -> Void

    var body: some View {
        let isArmed = shelf.armed == .clear
        Button(action: onClear) {
            Text(isArmed ? "Clear?" : "Clear")
                .foregroundStyle(isArmed ? Color.white : Color.primary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(isArmed ? Color.red : Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.medium))
        .fixedSize()
        .help(isArmed ? "Click again to clear. Originals stay where they are." : "Remove every item")
        .onHover { inside in if !inside, isArmed { shelf.disarm() } }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: isArmed)
    }
}
