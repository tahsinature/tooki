import AppKit
import SwiftUI

/// The compact thumbnail and label carried under the pointer during a drag.
struct DragPreviewCard<Thumbnail: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let thumbnail: Thumbnail

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 40, height: 40)
                .foregroundStyle(PanelTheme.secondaryText)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PanelTheme.primaryText)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 240)
        .background(PanelTheme.barBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PanelTheme.popupBorder))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .padding(10)
    }

    @MainActor
    func image(appearance: NSAppearance) -> NSImage? {
        let scheme: ColorScheme = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        let renderer = ImageRenderer(content: environment(\.colorScheme, scheme))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }
}
