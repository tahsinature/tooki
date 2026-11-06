import SwiftUI

/// The shelves that are open now, each with Show and Clear, plus New Shelf and Clear All.
struct ShelfListSection: View {
    let app: AppController

    private var library: ShelfLibrary { app.shelves }
    private var windows: ShelfWindows { app.shelfWindows }

    var body: some View {
        Section {
            if library.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("No shelves open").font(.headline)
                        Text("Hold Shift while dragging anything, or click New Shelf.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(library.shelves) { shelf in
                LabeledContent {
                    Button("Show") { windows.show(shelf) }
                    Button("Clear") { windows.close(shelf) }
                } label: {
                    Label {
                        Text(shelf.name)
                        Text(summary(of: shelf))
                    } icon: {
                        Image(systemName: "tray.full.fill").foregroundStyle(Color.accentColor)
                    }
                }
            }
        } header: {
            HStack {
                Text(library.isEmpty ? "Shelves" : "\(ShelfText.shelfCount(library.shelves.count)) Open")
                Spacer()
                Button("New Shelf") { windows.newShelf() }
                Button("Clear All…") { windows.confirmCloseAll() }
                    .disabled(library.isEmpty)
            }
            .controlSize(.small)
        }
    }

    private func summary(of shelf: Shelf) -> String {
        let count = ShelfText.itemCount(shelf.items.count).lowercased()
        let bytes = shelf.totalBytes
        return bytes > 0 ? "\(count) · \(bytes.formatted(.byteCount(style: .file)))" : count
    }
}
