import AppKit
import SwiftUI
import TookiKit

/// One icon shown in the Thaw Bar.
struct ThawBarEntry: Identifiable {
    let id: Int
    let item: MenuBarItem
    let image: NSImage

    /// Uses a picture of the icon when allowed, otherwise its app's icon.
    @MainActor
    init(id: Int, item: MenuBarItem, captureImage: Bool) {
        self.id = id
        self.item = item
        image = (captureImage ? MenuBarItemImageCapture.image(of: item) : nil) ?? Self.appIcon(for: item)
    }

    private static func appIcon(for item: MenuBarItem) -> NSImage {
        let icon = NSRunningApplication(processIdentifier: item.pid)?.icon
            ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)
            ?? NSImage()
        icon.size = CGSize(width: 18, height: 18)
        return icon
    }
}

struct ThawBarView: View {
    let entries: [ThawBarEntry]
    let style: ThawBarStyle
    let onPress: (MenuBarItem) -> Void

    var body: some View {
        HStack(spacing: 2) {
            if entries.isEmpty {
                Text("No hidden icons")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            ForEach(entries) { entry in
                ThawBarButton(entry: entry) { onPress(entry.item) }
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 32)
        .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
        .fixedSize()
    }

    private var background: AnyShapeStyle {
        switch style {
        case .material: AnyShapeStyle(.regularMaterial)
        case .solid: AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct ThawBarButton: View {
    let entry: ThawBarEntry
    let action: () -> Void
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: entry.image)
                .frame(height: 24)
                .padding(.horizontal, 3)
                .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(entry.item.title)
        .onHover { isHovered = $0 }
    }
}
