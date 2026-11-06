import SwiftUI

/// Explains the two kinds of shelf items and every way to add them, so nobody has to guess
/// whether dragging something out will move their file.
struct ShelfHowItWorksSection: View {
    var body: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    linkCard
                    copyCard
                }
                // Two 260-point cards with a 12-point gap.
                .frame(minWidth: 532, idealWidth: 532)

                VStack(spacing: 12) {
                    linkCard
                    copyCard
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("How it works")
        } footer: {
            Text("Each item on the shelf shows its kind as a small badge on its icon. Hover over an item to see where it came from. Dropped text, links and images are always saved as copies.")
                .foregroundStyle(.secondary)
        }

        Section("Ways to add") {
            ShelfWayRow(symbol: "hand.point.up.left", color: .indigo, title: "Drag onto the shelf") {
                Text("Drop on the left half to link to the original, or on the right half to make a copy. Hold Shift while dragging to bring the shelf up.")
            }
            ShelfWayRow(symbol: "command", color: .blue, title: "Paste with ⌘V") {
                Text("Copied files are added as links to the originals.")
            }
            ShelfWayRow(symbol: "link", color: .teal, title: "Links and scripts") {
                Text("`tooki://shelf/add?path=…` adds originals. Add `&mode=copy`, or run `tooki-shelf -c`, to add copies.")
            }
            ShelfWayRow(symbol: "terminal", color: .gray, title: "yazi") {
                Text("Press `T s` to add a copy of the selection, or `T S` to add the originals.")
            }
        }
    }

    private var linkCard: some View {
        ShelfKindCard(
            symbol: "arrow.up.right", color: .orange, title: "Link to original",
            facts: [
                ("folder", "Stays where it is. The shelf only points to it."),
                ("hand.draw", "Dragging it out uses the real file, so dropping it on a folder moves it."),
                ("xmark.circle", "Removing it from the shelf leaves the file alone."),
            ],
            bestFor: "Moving files into place, or anything too big to copy."
        )
    }

    private var copyCard: some View {
        ShelfKindCard(
            symbol: "doc.on.doc.fill", color: .green, title: "Copy",
            facts: [
                ("externaldrive", "Tooki keeps its own copy, so the shelf survives restarts and reboots."),
                ("hand.draw", "Dragging it out hands over the copy. Your original never moves."),
                ("trash", "Removing it deletes Tooki's copy. Dragged-out copies are kept a minute so uploads can finish."),
            ],
            bestFor: "Sharing, uploading or attaching without touching the original."
        )
    }
}

private struct ShelfKindCard: View {
    let symbol: String
    let color: Color
    let title: String
    let facts: [(symbol: String, text: String)]
    let bestFor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconTile(symbol: symbol, color: color, size: 24)
                Text(title).font(.headline)
            }
            ForEach(facts, id: \.text) { fact in
                Label {
                    Text(fact.text).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: fact.symbol).foregroundStyle(color)
                }
                .font(.callout)
            }
            Text("Best for: \(bestFor)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.3)))
    }
}

private struct ShelfWayRow<Detail: View>: View {
    let symbol: String
    let color: Color
    let title: String
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                detail
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
