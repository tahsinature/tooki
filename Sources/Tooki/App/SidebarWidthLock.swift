import AppKit

/// Keeps the settings sidebar at a fixed width so its divider can't be dragged.
///
/// SwiftUI ignores `navigationSplitViewColumnWidth` limits on macOS 26 and keeps resetting
/// the sidebar's split view item, so this watches the item and puts the limits back.
@MainActor
final class SidebarWidthLock {
    private let width: CGFloat
    private weak var splitView: NSSplitView?
    private weak var sidebar: NSSplitViewItem?
    private var observations: [NSKeyValueObservation] = []

    init?(window: NSWindow, width: CGFloat) {
        guard let contentView = window.contentView,
              let splitView = Self.firstSplitView(in: contentView),
              let controller = splitView.delegate as? NSSplitViewController,
              let sidebar = controller.splitViewItems.first
        else { return nil }
        self.width = width
        self.splitView = splitView
        self.sidebar = sidebar
        apply()
        observations = [
            sidebar.observe(\.minimumThickness) { [weak self] _, _ in self?.applyOnMain() },
            sidebar.observe(\.maximumThickness) { [weak self] _, _ in self?.applyOnMain() },
            sidebar.observe(\.canCollapse) { [weak self] _, _ in self?.applyOnMain() },
        ]
    }

    private nonisolated func applyOnMain() {
        MainActor.assumeIsolated { apply() }
    }

    private func apply() {
        guard let splitView, let sidebar else { return }
        if sidebar.canCollapse { sidebar.canCollapse = false }
        if sidebar.minimumThickness != width { sidebar.minimumThickness = width }
        if sidebar.maximumThickness != width { sidebar.maximumThickness = width }
        // The limits don't resize a sidebar that's already narrower or wider, so move the divider too.
        splitView.setPosition(width, ofDividerAt: 0)
    }

    private static func firstSplitView(in view: NSView) -> NSSplitView? {
        if let splitView = view as? NSSplitView { return splitView }
        return view.subviews.lazy.compactMap(firstSplitView).first
    }
}
