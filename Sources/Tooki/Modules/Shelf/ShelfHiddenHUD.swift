import AppKit
import SwiftUI

/// A short note where a shelf was just hidden, so it doesn't look deleted.
@MainActor
enum ShelfHiddenHUD {
    private static var panel: NSPanel?
    private static var fading: Task<Void, Never>?

    static func show(where frame: CGRect) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let size = panel.contentView?.fittingSize ?? .zero
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }

        fading?.cancel()
        fading = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { $0.duration = 0.3; panel.animator().alphaValue = 0 }
            if !Task.isCancelled { panel.orderOut(nil) }
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        // Above the shelves, which float too, so a neighbouring shelf can't cover it.
        panel.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView())
        return panel
    }

    private struct HUDView: View {
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 13, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Shelf hidden").font(.callout.weight(.semibold))
                    Text("Open it from the menu bar.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
            .fixedSize()
        }
    }
}
