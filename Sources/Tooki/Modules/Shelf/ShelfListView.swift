import AppKit
import SwiftUI

/// The expanded shelf: every item in a list. Click to select (⌘ or ⇧ to select more),
/// then drag the selection out. Double-click opens an item.
struct ShelfListView: View {
    let shelf: Shelf
    let onClose: () -> Void

    private static let rowHeight: CGFloat = 44
    private static let maxVisibleRows = 7

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(shelf.items) { item in
                        ShelfRow(item: item, isSelected: shelf.selection.contains(item.id), shelf: shelf)
                            .frame(height: Self.rowHeight)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(height: CGFloat(min(shelf.items.count, Self.maxVisibleRows)) * Self.rowHeight)
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.headline)
            Spacer()
            ShelfCircleButton(symbol: "chevron.up", help: "Show as a stack") { shelf.isExpanded = false }
            ShelfCircleButton(symbol: "xmark", help: "Clear and close the shelf", action: onClose)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var title: String {
        let count = ShelfText.itemCount(shelf.items.count)
        return shelf.selection.isEmpty ? count : "\(count) · \(shelf.selection.count) selected"
    }

    private var footer: some View {
        HStack {
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear", action: onClose)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summary: String {
        let count = ShelfText.itemCount(shelf.items.count).lowercased()
        let bytes = shelf.totalBytes
        return bytes > 0 ? "\(count) · \(bytes.formatted(.byteCount(style: .file)))" : count
    }
}

private struct ShelfRow: View {
    let item: ShelfItem
    let isSelected: Bool
    let shelf: Shelf

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 28, height: 28)
                .overlay(alignment: .bottomTrailing) { ShelfKindBadge(isCopy: item.isCopy) }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if shelf.copyingIDs.contains(item.id) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .tint(.green)
                        .help("Copying…")
                } else {
                    HStack(spacing: 0) {
                        Text(item.detail)
                            .layoutPriority(1)
                        if let location = item.location {
                            Text(" · \(location)")
                                .truncationMode(.middle)
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 2)
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
                onDropped: { shelf.didDragOut($0) }
            )
        )
    }
}

/// A small corner mark on the icon: an arrow for a link to the original, two pages for Tooki's copy.
private struct ShelfKindBadge: View {
    let isCopy: Bool

    var body: some View {
        Image(systemName: isCopy ? "doc.on.doc.fill" : "arrow.up.right")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 14, height: 14)
            .background(isCopy ? Color.green : Color.orange, in: Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            .offset(x: 4, y: 4)
    }
}
