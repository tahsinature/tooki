import AppKit
import TookiDesignSystem
import TookiKit

/// Assign identity in the layout planner's left-to-right order before sorting for display.
/// Repeated titles remain separate rows with their own native click targets.
@MainActor
enum MenuBarSearchItemFactory {
    static func items(from source: [MenuBarItem], boundary: CGFloat?,
                      onPress: @escaping @MainActor (MenuBarItem) -> Void) -> [SearchItem] {
        let ordered = source.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return ($0.windowID ?? 0) < ($1.windowID ?? 0)
        }
        let ids = MenuBarLayoutPlanner.ids(for: ordered.map {
            MenuBarItemDescriptor(bundleID: $0.bundleID, identifier: $0.identifier, appName: $0.appName)
        })
        func isHidden(_ item: MenuBarItem) -> Bool {
            boundary.map { item.frame.midX < $0 } ?? !item.isOnScreen
        }
        return zip(ordered, ids).sorted { first, second in
            let firstHidden = isHidden(first.0)
            let secondHidden = isHidden(second.0)
            return firstHidden == secondHidden ? first.0.frame.minX > second.0.frame.minX : !firstHidden
        }.map { item, id in
            let icon = NSRunningApplication(processIdentifier: item.pid)?.icon
            return SearchItem(
                id: "menubar-\(id)", title: item.title,
                kind: isHidden(item) ? "Hidden" : "Shown", group: .menuBar,
                icon: icon.map(PanelIcon.image) ?? .symbol("menubar.rectangle"),
                searchText: "\(item.appName) \(item.label) \(item.bundleID ?? "")",
                actionTitle: "Click Item", run: { onPress(item) }
            )
        }
    }
}
