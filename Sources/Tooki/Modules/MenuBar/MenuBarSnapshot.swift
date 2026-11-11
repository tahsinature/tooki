import AppKit
import TookiKit

/// The menu bar icons at one moment, left to right, with Tooki's dividers among them.
struct MenuBarSnapshot {
    struct Icon {
        let id: String
        let title: String
        let bundleID: String?
        let frame: CGRect
        let section: MenuBarSection
        /// Where moves are aimed, when the icon's window is known.
        let target: MenuBarItemEvents.Target?
    }

    /// Icons macOS keeps in place, so they're left out of layouts.
    private static let fixedIdentifiers: Set<String> = ["com.apple.menuextra.controlcenter", "com.apple.menuextra.clock"]

    let icons: [Icon]
    /// Tooki's dividers, keyed by their layout IDs.
    let dividers: [String: Icon]

    /// IDs left to right, including the dividers.
    var order: [String] {
        (icons + dividers.values).sorted { $0.frame.minX < $1.frame.minX }.map(\.id)
    }

    var layout: MenuBarLayout {
        func ids(_ section: MenuBarSection) -> [String] { icons.filter { $0.section == section }.map(\.id) }
        return MenuBarLayout(shown: ids(.shown), hidden: ids(.hidden), alwaysHidden: ids(.alwaysHidden))
    }

    @MainActor
    static func capture(organizer: MenuBarOrganizer) async -> MenuBarSnapshot {
        let items = await MenuBarItemScanner.scan()
            .filter { !fixedIdentifiers.contains($0.identifier ?? "") }
            .sorted { $0.currentFrame.minX < $1.currentFrame.minX }
        let ids = MenuBarLayoutPlanner.ids(for: items.map {
            MenuBarItemDescriptor(bundleID: $0.bundleID, identifier: $0.identifier, appName: $0.appName)
        })
        let icons = zip(ids, items).map { id, item in
            Icon(
                id: id, title: item.title, bundleID: item.bundleID, frame: item.currentFrame,
                section: organizer.section(of: item),
                target: item.windowID.map { MenuBarItemEvents.Target(windowID: $0, pid: item.eventPID) }
            )
        }
        var dividers: [String: Icon] = [:]
        for (id, divider) in organizer.dividers {
            guard let frame = divider.frame else { continue }
            dividers[id] = Icon(
                id: id, title: "Tooki divider", bundleID: nil, frame: frame, section: divider.section, target: divider.eventTarget
            )
        }
        return MenuBarSnapshot(icons: icons, dividers: dividers)
    }

    func icon(_ id: String) -> Icon? {
        dividers[id] ?? icons.first { $0.id == id }
    }

    /// Shown icons that sit under the notch, where nobody can see or click them.
    var iconsUnderNotch: [Icon] {
        let notches = NSScreen.screens.compactMap(\.notchRange)
        return icons.filter { icon in
            icon.section == .shown && notches.contains { $0.overlaps(icon.frame.minX...icon.frame.maxX) }
        }
    }
}
