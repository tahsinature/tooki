import SwiftUI

/// What's being dragged over the shelf. Files get a choice between linking and copying;
/// text, links and images are always saved as Tooki's own files.
enum ShelfDropTarget: Equatable {
    case files(ShelfAddMode)
    case content
}

/// Covers the shelf while something is dragged over it. The empty shelf has the same size,
/// so the box doesn't jump when a drag arrives.
struct ShelfDropZone: View {
    static let size = CGSize(width: ShelfMotion.width, height: 150)

    let target: ShelfDropTarget

    var body: some View {
        Group {
            switch target {
            case .files(let mode):
                HStack(spacing: 6) {
                    ShelfDropHalf(
                        symbol: "arrow.up.right", title: "Link to original", detail: "Moves when dragged out",
                        color: .orange, isActive: mode == .original
                    )
                    ShelfDropHalf(
                        symbol: "doc.on.doc", title: "Make a copy", detail: "Original stays put",
                        color: .green, isActive: mode == .copy
                    )
                }
            case .content:
                ShelfDropHalf(
                    symbol: "plus.circle", title: "Save to shelf", detail: "Text, links and images are kept as a copy.",
                    color: .accentColor, isActive: true
                )
            }
        }
        .padding(8)
    }
}

/// One side of the drop zone, colored like the badge its items get in the list.
private struct ShelfDropHalf: View {
    let symbol: String
    let title: String
    let detail: String
    let color: Color
    let isActive: Bool

    private let shape = RoundedRectangle(cornerRadius: 10)

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? color : .secondary)
            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isActive ? color.opacity(0.2) : Color.primary.opacity(0.04), in: shape)
        .overlay(
            shape.strokeBorder(
                isActive ? color : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: isActive ? 2 : 1, dash: isActive ? [] : [5, 4])
            )
        )
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}
