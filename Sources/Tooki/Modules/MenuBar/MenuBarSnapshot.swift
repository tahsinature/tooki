import AppKit
import TookiKit

/// The menu bar icons at one moment, left to right, with Tooki's separator among them.
struct MenuBarSnapshot {
    struct Icon {
        let id: String
        let title: String
        let bundleID: String?
        let frame: CGRect
        let isHidden: Bool
    }

    /// Icons macOS keeps in place, so they're left out of layouts.
    private static let fixedIdentifiers: Set<String> = ["com.apple.menuextra.controlcenter", "com.apple.menuextra.clock"]

    let icons: [Icon]
    let separatorFrame: CGRect?
    let toggleFrame: CGRect?

    /// IDs left to right, including Tooki's separator and toggle.
    var order: [String] {
        let tookiItems = [(MenuBarLayoutPlanner.separatorID, separatorFrame), (MenuBarLayoutPlanner.toggleID, toggleFrame)]
            .compactMap { id, frame in frame.map { (id, $0.minX) } }
        return (icons.map { ($0.id, $0.frame.minX) } + tookiItems)
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    var layout: MenuBarLayout {
        MenuBarLayout(shown: icons.filter { !$0.isHidden }.map(\.id), hidden: icons.filter(\.isHidden).map(\.id))
    }

    static func capture(separatorFrame: CGRect?, toggleFrame: CGRect? = nil) async -> MenuBarSnapshot {
        let items = await MenuBarItemScanner.scan()
            .filter { !fixedIdentifiers.contains($0.identifier ?? "") }
            .sorted { $0.frame.minX < $1.frame.minX }
        let ids = MenuBarLayoutPlanner.ids(for: items.map {
            MenuBarItemDescriptor(bundleID: $0.bundleID, identifier: $0.identifier, appName: $0.appName)
        })
        let boundary = separatorFrame?.minX ?? -.infinity
        let icons = zip(ids, items).map { id, item in
            Icon(id: id, title: item.title, bundleID: item.bundleID, frame: item.frame, isHidden: item.frame.midX < boundary)
        }
        return MenuBarSnapshot(icons: icons, separatorFrame: separatorFrame, toggleFrame: toggleFrame)
    }

    func frame(of id: String) -> CGRect? {
        switch id {
        case MenuBarLayoutPlanner.separatorID: separatorFrame
        case MenuBarLayoutPlanner.toggleID: toggleFrame
        default: icons.first { $0.id == id }?.frame
        }
    }

    /// Where to drop an icon so it lands next to the anchor.
    /// The menu bar swaps icons as the cursor crosses their middle, so staying near the anchor's edge is enough.
    func dropX(for placement: MenuBarLayoutPlanner.Placement) -> CGFloat? {
        switch placement {
        case .before(let anchor): frame(of: anchor).map { $0.minX + 2 }
        case .after(let anchor): frame(of: anchor).map { $0.maxX - 2 }
        }
    }

    /// Shown icons that sit under the notch, where nobody can see or click them.
    var iconsUnderNotch: [Icon] {
        let notches = NSScreen.screens.compactMap(\.notchRange)
        return icons.filter { icon in
            !icon.isHidden && notches.contains { $0.overlaps(icon.frame.minX...icon.frame.maxX) }
        }
    }
}

private extension NSScreen {
    /// The notch's horizontal extent in screen coordinates, on Macs that have one.
    var notchRange: ClosedRange<CGFloat>? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea, left.maxX < right.minX else { return nil }
        return (frame.minX + left.maxX)...(frame.minX + right.minX)
    }
}
