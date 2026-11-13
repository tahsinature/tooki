import SwiftUI

/// Explains the two kinds of shelf items and every way to add them, so nobody has to guess
/// whether dragging something out will move their file.
struct ShelfHowItWorksSection: View {
    var body: some View {
        SettingsSection("How it works") {
            ShelfKindTable()
        } footer: {
            Text("Each item shows its kind as a badge on its icon; hover to see where it came from. Dropped text, links and images are always saved as copies.")
        }

        SettingsSection("Ways to add") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    ShelfWayTile(symbol: "hand.point.up.left", color: .indigo, title: "Drag onto the shelf") {
                        Text("Left half links, right half copies. Hold Shift while dragging to bring it up.")
                    }
                    ShelfWayTile(symbol: "command", color: .blue, title: "Paste with ⌘V") {
                        Text("Copied files are added as links to the originals.")
                    }
                }
                GridRow {
                    ShelfWayTile(symbol: "link", color: .teal, title: "Links and scripts") {
                        Text("`tooki://shelf/add?path=…` links. Add `&mode=copy` or run `tooki-shelf -c` for copies.")
                    }
                    ShelfWayTile(symbol: "terminal", color: .gray, title: "yazi") {
                        Text("`T s` adds a copy of the selection, `T S` adds the originals.")
                    }
                }
            }
            .padding(8)
        }
    }
}

/// Link and Copy side by side, one row per behavior that differs.
private struct ShelfKindTable: View {
    private let rows: [(label: String, link: String, copy: String)] = [
        ("The file", "Stays where it is; the shelf points to it", "Tooki keeps its own copy, safe across restarts"),
        ("Drag out", "Uses the real file, so a folder drop moves it", "Hands over the copy; your original never moves"),
        ("Remove", "Leaves the file alone", "Deletes Tooki's copy (kept a minute for uploads)"),
        ("Best for", "Moving files into place, or anything big", "Sharing, uploading or attaching"),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                header(symbol: "arrow.up.right", color: .orange, title: "Link to original")
                header(symbol: "doc.on.doc.fill", color: .green, title: "Copy")
            }
            .padding(.bottom, 8)
            ForEach(rows, id: \.label) { row in
                Divider()
                GridRow(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .font(SettingsTheme.rowDescriptionFont.weight(.semibold))
                        .foregroundStyle(SettingsTheme.secondaryText)
                    cell(row.link)
                    cell(row.copy)
                }
                .padding(.vertical, 7)
            }
        }
    }

    private func header(symbol: String, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            IconTile(symbol: symbol, color: color, size: 20)
            Text(title).font(SettingsTheme.rowTitleFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ text: String) -> some View {
        Text(text)
            .font(SettingsTheme.controlFont)
            .foregroundStyle(SettingsTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShelfWayTile<Detail: View>: View {
    let symbol: String
    let color: Color
    let title: String
    @ViewBuilder let detail: Detail

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SettingsTheme.rowTitleFont)
                detail
                    .font(SettingsTheme.rowDescriptionFont)
                    .foregroundStyle(SettingsTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: SettingsTheme.controlRadius + 2))
    }
}
