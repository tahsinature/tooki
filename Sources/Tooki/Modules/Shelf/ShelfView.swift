import AppKit
import SwiftUI

/// The shelf's content: a drop zone when empty, a stack of items, or the item list.
/// It sizes itself, and reports its size so the panel can follow.
struct ShelfView: View {
    let shelf: Shelf
    let onClose: () -> Void
    let onSizeChange: (CGSize) -> Void

    private let shape = RoundedRectangle(cornerRadius: 14)

    var body: some View {
        content
            .opacity(isDropping ? 0 : 1)
            .frame(
                minWidth: isDropping ? ShelfDropZone.size.width : nil,
                minHeight: isDropping ? ShelfDropZone.size.height : nil
            )
            .overlay {
                if let target = shelf.dropTarget { ShelfDropZone(target: target) }
            }
            .background(.thinMaterial, in: shape)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    isDropping ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isDropping ? 2 : 1
                )
            )
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size) { onSizeChange($0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var isDropping: Bool { shelf.dropTarget != nil }

    /// While dropping, the content stays underneath (hidden) so the drop zone is at least as big as the shelf.
    @ViewBuilder
    private var content: some View {
        if shelf.isEmpty {
            ShelfEmptyView()
        } else if shelf.isExpanded {
            ShelfListView(shelf: shelf, onClose: onClose)
        } else {
            ShelfStackView(shelf: shelf, onClose: onClose)
        }
    }
}

/// The collapsed shelf: a pile of the latest items. Drag the pile to take everything along.
private struct ShelfStackView: View {
    let shelf: Shelf
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ShelfCircleButton(symbol: "xmark", help: "Clear and close the shelf", action: onClose)
                Spacer()
                ShelfCircleButton(symbol: "chevron.down", help: "Show the items") { shelf.isExpanded = true }
            }
            Spacer(minLength: 0)
            ShelfPile(items: shelf.items.suffix(3))
                .frame(width: 100, height: 84)
                .overlay(
                    ShelfDragArea(
                        items: { shelf.items },
                        onClick: { _ in shelf.isExpanded = true },
                        onDropped: { shelf.didDragOut($0) }
                    )
                )
                .help("Drag to move every item, or click to see them")
            Spacer(minLength: 0)
            Button { shelf.isExpanded = true } label: {
                HStack(spacing: 3) {
                    Text(ShelfText.itemCount(shelf.items.count))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 168, height: 168)
    }
}

/// Up to three file icons fanned out like a small pile, the newest on top.
private struct ShelfPile: View {
    let items: ArraySlice<ShelfItem>

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let depth = Double(items.count - 1 - index)
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(depth * -8))
                    .offset(x: depth * -6, y: depth * 4)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
        }
    }
}

/// Shown when the shelf is opened with nothing on it. Same size as the drop zone that replaces it.
private struct ShelfEmptyView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Drop files here")
                .font(.callout.weight(.semibold))
            Text("or press ⌘V to paste")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.tertiary)
        )
        .padding(8)
        .frame(width: ShelfDropZone.size.width, height: ShelfDropZone.size.height)
    }
}

struct ShelfCircleButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

enum ShelfText {
    static func itemCount(_ count: Int) -> String {
        count == 1 ? "1 Item" : "\(count) Items"
    }
}
