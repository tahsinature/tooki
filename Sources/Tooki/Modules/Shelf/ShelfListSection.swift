import SwiftUI

/// The shelves that are open now, each with Show and Clear, plus New Shelf and Clear All.
struct ShelfListSection: View {
    let app: AppController

    private var library: ShelfLibrary { app.shelves }
    private var windows: ShelfWindows { app.shelfWindows }

    var body: some View {
        SettingsSection(library.isEmpty ? "Shelves" : "\(ShelfText.shelfCount(library.shelves.count)) Open") {
            if library.isEmpty {
                SettingsCardRow {
                    HStack(spacing: 14) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        SettingsRowLabel(
                            title: "No shelves open",
                            description: "Hold Shift while dragging anything, or click New Shelf."
                        )
                    }
                }
            }
            ForEach(library.shelves) { shelf in
                SettingsRow(shelf.name, description: summary(of: shelf)) {
                    HStack {
                        Button("Show") { windows.show(shelf) }
                        Button("Clear") { windows.close(shelf) }
                    }
                }
            }
            SettingsCardRow {
                HStack {
                    Button("New Shelf") { windows.newShelf() }
                    Button("Clear All…") { windows.confirmCloseAll() }
                        .disabled(library.isEmpty)
                }
            }
        }
    }

    private func summary(of shelf: Shelf) -> String {
        let count = ShelfText.itemCount(shelf.items.count).lowercased()
        let bytes = shelf.totalBytes
        return bytes > 0 ? "\(count) · \(bytes.formatted(.byteCount(style: .file)))" : count
    }
}
