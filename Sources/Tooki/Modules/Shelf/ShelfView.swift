import AppKit
import SwiftUI

/// The shelf's content: a drop zone when empty, a stack of items, or the item list.
/// It sizes itself, and reports its size so the panel can follow.
struct ShelfView: View {
    let shelf: Shelf
    let onHide: () -> Void
    let onDelete: () -> Void
    let onClear: () -> Void
    let onSizeChange: (CGSize) -> Void

    @Namespace private var namespace
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
            .overlay { if isHolding { ShelfHoldOverlay() } }
            .clipShape(shape)
            .overlay { if isFocused { ShelfFocusGlow(shape: shape) } }
            .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
            .scaleEffect(scale)
            .blur(radius: shelf.leaving == .closing ? 12 : 0)
            .offset(y: shelf.leaving == .hiding ? 16 : 0)
            .opacity(shelf.leaving == nil ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isFocused)
            // Shrinks slowly while Esc is held, and springs back when it's let go.
            .animation(holdAnimation, value: isHolding)
            .animation(.easeIn(duration: ShelfMotion.leave), value: shelf.leaving)
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size) { onSizeChange($0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var isDropping: Bool { shelf.dropTarget != nil }
    private var isHolding: Bool { shelf.isHoldingToDelete }
    private var isFocused: Bool { shelf.isFocused && !isDropping && !isHolding }

    private var scale: CGFloat {
        if isHolding { return 0.88 }
        return shelf.leaving == .closing ? 0.5 : 1
    }

    /// Letting go of Esc springs back, unless the shelf is already on its way out.
    private var holdAnimation: Animation {
        if isHolding { return .linear(duration: ShelfMotion.holdToDelete) }
        if shelf.leaving != nil { return .easeIn(duration: ShelfMotion.leave) }
        return .spring(duration: 0.4, bounce: 0.5)
    }

    private var borderColor: Color {
        if isHolding { return .red }
        if isDropping || isFocused { return .accentColor }
        return Color(nsColor: .separatorColor)
    }

    private var borderWidth: CGFloat {
        if isDropping || isHolding { return 2 }
        return isFocused ? 1.5 : 1
    }

    /// While dropping, the content stays underneath (hidden) so the drop zone is at least as big as the shelf.
    @ViewBuilder
    private var content: some View {
        if shelf.isEmpty {
            ShelfEmptyView()
        } else {
            VStack(spacing: 0) {
                ShelfHeader(shelf: shelf, onHide: onHide, onDelete: onDelete, onClear: onClear)
                if shelf.isExpanded {
                    ShelfPages(shelf: shelf, namespace: namespace)
                    Divider()
                    ShelfFooter(shelf: shelf, onClear: onClear)
                } else {
                    ShelfStack(shelf: shelf, namespace: namespace)
                    ShelfShowAllBar(shelf: shelf, onClear: onClear)
                }
            }
            .frame(width: ShelfMotion.width)
            .animation(ShelfMotion.spring, value: shelf.isExpanded)
        }
    }
}

/// The list and an item's details side by side, like pages: → slides the details in from the
/// right, ← slides back. The height springs to fit whichever page is showing.
private struct ShelfPages: View {
    let shelf: Shelf
    let namespace: Namespace.ID

    private var isShowingDetail: Bool { shelf.detailItem != nil }

    var body: some View {
        ShelfPagesLayout(page: isShowingDetail ? 1 : 0) {
            ShelfRows(shelf: shelf, namespace: namespace)
                .allowsHitTesting(!isShowingDetail)
            Group {
                // The cursor's item even while hidden: ready to slide in, and it stays put sliding out.
                if let item = shelf.cursorItem ?? shelf.items.first {
                    ShelfItemDetail(item: item, shelf: shelf)
                }
            }
            .allowsHitTesting(isShowingDetail)
        }
        .clipped()
        .animation(ShelfMotion.spring, value: isShowingDetail)
    }
}

/// Places its subviews in a row, each one shelf wide, scrolled to `page`. Its height is the
/// shown page's height, blended between pages while `page` animates.
private struct ShelfPagesLayout: Layout {
    var page: CGFloat

    var animatableData: CGFloat {
        get { page }
        set { page = newValue }
    }

    private var width: CGFloat { ShelfMotion.width }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        guard !heights.isEmpty else { return CGSize(width: width, height: 0) }
        let lower = min(Int(page), heights.count - 1)
        let upper = min(lower + 1, heights.count - 1)
        let fraction = page - CGFloat(lower)
        let height = heights[lower] + (heights[upper] - heights[lower]) * fraction
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + (CGFloat(index) - page) * width
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: nil))
        }
    }
}

/// A soft glow inside the edge while the shelf has keyboard focus.
private struct ShelfFocusGlow<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 6)
            .blur(radius: 5)
            .clipShape(shape)
            .allowsHitTesting(false)
    }
}

/// While Esc is held: the shelf turns red and says what's about to happen.
private struct ShelfHoldOverlay: View {
    var body: some View {
        ZStack {
            Color.red.opacity(0.35)
            VStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text("Keep holding Esc to delete")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .shadow(radius: 4)
        }
        .allowsHitTesting(false)
    }
}

/// How the shelf moves between the stack and the list: one width, a spring on the height.
enum ShelfMotion {
    static let width: CGFloat = 300
    static let duration = 0.35
    static let spring = Animation.spring(duration: duration, bounce: 0.15)
    /// Esc has to be held this long before the shelf starts turning red, so a tap never flashes.
    static let holdDelay = Duration.milliseconds(250)
    /// Then this many seconds more to delete the shelf.
    static let holdToDelete = 1.0
    /// How long hiding or closing a shelf takes.
    static let leave = 0.22
}

/// The collapsed shelf: a pile of the latest items next to their names. Drag the pile to take
/// everything along; only Show opens the list. The icons fly into their rows when it opens.
private struct ShelfStack: View {
    let shelf: Shelf
    let namespace: Namespace.ID
    @State private var isHovered = false

    private static let namesShown = 3

    var body: some View {
        // Centered as a group; the space around them moves the window.
        HStack(spacing: 18) {
            pile
            names
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .shelfWindowDragArea()
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private var pile: some View {
        ShelfPile(items: shelf.items.suffix(Self.namesShown), namespace: namespace, isFanned: isHovered)
            .frame(width: 78, height: 68)
            .overlay(
                ShelfDragArea(
                    items: { shelf.items },
                    menu: { ShelfItemMenu.make(for: shelf.items, on: shelf) },
                    onDropped: { shelf.didDragOut($0) }
                )
            )
            .help("Drag to move every item")
            .onHover { hovering in
                guard hovering != isHovered else { return }
                isHovered = hovering
                hovering ? NSCursor.openHand.push() : NSCursor.pop()
            }
            // Unfolding removes the pile while the pointer may still be on it.
            .onDisappear {
                if isHovered { NSCursor.pop() }
                isHovered = false
            }
            .animation(.spring(duration: 0.25, bounce: 0.3), value: isHovered)
    }

    /// The newest items first, each with a dot in its Original or Copy color.
    private var names: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(shelf.items.suffix(Self.namesShown).reversed()) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.isCopy ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(item.name)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            let hidden = shelf.items.count - Self.namesShown
            if hidden > 0 {
                Text("+ \(hidden) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
        }
    }
}

/// The folded shelf's bottom row: a wide button that opens the list and says what's in it, and Clear.
private struct ShelfShowAllBar: View {
    let shelf: Shelf
    let onClear: () -> Void

    @State private var isHighlighted = false

    var body: some View {
        HStack(spacing: 8) {
            Button { shelf.isExpanded = true } label: {
                HStack(spacing: 4) {
                    Text("Show \(ShelfText.itemCount(shelf.items.count).lowercased())")
                        .fontWeight(.semibold)
                    if shelf.totalBytes > 0 {
                        Text("· \(shelf.totalBytes.formatted(.byteCount(style: .file)))")
                            .foregroundStyle(isHighlighted ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.caption)
                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(
                    isHighlighted ? Color.accentColor : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHighlighted = $0 }
            .animation(.easeOut(duration: 0.15), value: isHighlighted)
            ShelfClearButton(shelf: shelf, onClear: onClear)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

/// Up to three file icons fanned out like a small pile, the newest on top.
private struct ShelfPile: View {
    let items: ArraySlice<ShelfItem>
    let namespace: Namespace.ID
    /// Spreads the pile a little on hover, to show it can be opened.
    var isFanned = false

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let depth = Double(items.count - 1 - index) * (isFanned ? 1.8 : 1)
                ShelfItemIcon(item: item, size: 56)
                    .matchedGeometryEffect(id: item.id, in: namespace)
                    .rotationEffect(.degrees(depth * -8))
                    .offset(x: depth * -6, y: depth * 4)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
        }
        // The back items lean down and left; shift the whole pile back so it's centered.
        .offset(x: backDepth * 3, y: backDepth * -2)
    }

    private var backDepth: Double {
        Double(max(items.count - 1, 0)) * (isFanned ? 1.8 : 1)
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

    /// "5 items · 6.2 MB", or just the count when nothing has a size.
    @MainActor
    static func summary(of shelf: Shelf) -> String {
        let count = itemCount(shelf.items.count).lowercased()
        let bytes = shelf.totalBytes
        return bytes > 0 ? "\(count) · \(bytes.formatted(.byteCount(style: .file)))" : count
    }

    static func shelfCount(_ count: Int) -> String {
        count == 1 ? "1 Shelf" : "\(count) Shelves"
    }
}
