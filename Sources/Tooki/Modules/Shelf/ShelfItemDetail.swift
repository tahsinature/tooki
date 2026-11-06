import AppKit
import SwiftUI

/// One item's details, which the list slides over to: what it is, where it is now and where it
/// came from. ← or "All items" goes back; ↑ and ↓ step through the items without leaving.
struct ShelfItemDetail: View {
    let item: ShelfItem
    let shelf: Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { shelf.isShowingDetail = false } label: {
                    Label("All items", systemImage: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to the list (←)")
                Spacer()
                Text(position)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help("↑ and ↓ step through the items")
            }

            HStack(spacing: 10) {
                ShelfItemIcon(item: item, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    ShelfModeTag(isCopy: item.isCopy)
                }
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 7) {
                row("Mode", item.mode)
                row("Size", item.detail)
                row("Path", item.displayPath, copying: item.path)
                if let original = item.originalPath ?? (item.ownsFile ? nil : item.path) {
                    row("Original", item.displayOriginalPath ?? original, copying: original)
                } else {
                    row("Original", "None. Tooki made this file.")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .frame(width: ShelfMotion.width, alignment: .leading)
    }

    /// Where the item is on the shelf, like "2 / 3".
    private var position: String {
        let index = shelf.items.firstIndex { $0.id == item.id } ?? 0
        return "\(index + 1) / \(shelf.items.count)"
    }

    /// A label and its value. With `copying`, a small copy button follows the value.
    private func row(_ label: String, _ value: String, copying copyText: String? = nil) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.caption)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                if let copyText { ShelfCopyButton(text: copyText) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A tiny copy icon that turns into a checkmark for a moment once it has copied.
private struct ShelfCopyButton: View {
    let text: String

    @State private var didCopy = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                didCopy = false
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(didCopy ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy the full path")
        .animation(.easeOut(duration: 0.15), value: didCopy)
    }
}

/// "Original" in orange or "Copy" in green, matching the badges on the icons.
private struct ShelfModeTag: View {
    let isCopy: Bool

    var body: some View {
        let color = isCopy ? Color.green : Color.orange
        Text(isCopy ? "Copy" : "Original")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.18), in: Capsule())
    }
}
