import AppKit
import SwiftUI
import Testing
import SnapshotTesting
import TookiDesignSystem

@MainActor
struct DesignSystemTests {
    @Test func sharedRowStates() {
        _ = NSApplication.shared
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let view = NSHostingView(rootView: RowStates())
            view.appearance = NSAppearance(named: appearance)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            window.orderFront(nil)
            defer { window.orderOut(nil) }
            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            view.displayIfNeeded()
            assertSnapshot(of: view, as: .image, named: appearance.rawValue)
        }
    }
}

private struct RowStates: View {
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Pinned", isFirst: true)
            row("Selected", selected: true)
            row("Normal")
            row("Missing file", dimmed: true)
            SectionHeader(title: "Earlier")
            row("Delete", color: PanelTheme.danger)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PanelTheme.listInset)
        .background(PanelTheme.barBackground)
    }

    private func row(_ title: String, selected: Bool = false, dimmed: Bool = false,
                     color: Color = PanelTheme.primaryText) -> some View {
        ResultRow(title: title, isSelected: selected, isDimmed: dimmed, titleColor: color) {
            Image(systemName: "doc.text")
        } trailing: { Keycap(shortcut: "⌘K") }
    }
}

