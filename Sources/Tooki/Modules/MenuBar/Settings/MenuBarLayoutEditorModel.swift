import AppKit
import Observation
import TookiKit

/// One icon in the layout editor. Icons of apps that aren't running stay in the layout.
struct MenuBarLayoutRow: Identifiable, Hashable {
    let id: String
    let title: String
    let isRunning: Bool

    /// The app's bundle ID, without the "#2" that marks an app's second icon.
    var bundleID: String { id.split(separator: "#").first.map(String.init) ?? id }
    var isAppleItem: Bool { id.hasPrefix("com.apple.") }
}

/// The editable Always Hidden, Hidden and Shown lists, ordered left to right.
@MainActor
@Observable
final class MenuBarLayoutEditorModel {
    var alwaysHidden: [MenuBarLayoutRow] = []
    var hidden: [MenuBarLayoutRow] = []
    var shown: [MenuBarLayoutRow] = []
    private(set) var underNotch: Set<String> = []

    var layout: MenuBarLayout {
        MenuBarLayout(shown: shown.map(\.id), hidden: hidden.map(\.id), alwaysHidden: alwaysHidden.map(\.id))
    }

    /// Shows the saved layout, adding icons it doesn't know yet where they currently are.
    /// With no saved layout, or `fromMenuBar`, shows the menu bar as it is now.
    func load(saved: MenuBarLayout?, organizer: MenuBarOrganizer, fromMenuBar: Bool = false) async {
        let snapshot = await MenuBarSnapshot.capture(organizer: organizer)
        let current = snapshot.layout
        var base = fromMenuBar ? current : saved ?? current
        if !organizer.hasAlwaysHiddenSection {
            base = MenuBarLayout(shown: base.shown, hidden: base.alwaysHidden + base.hidden)
        }
        let known = Set(base.shown + base.hidden + base.alwaysHidden)
        let iconsByID = Dictionary(snapshot.icons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func rows(_ currentIDs: [String], _ savedIDs: [String]) -> [MenuBarLayoutRow] {
            (currentIDs.filter { !known.contains($0) } + savedIDs).map { id in
                MenuBarLayoutRow(id: id, title: iconsByID[id]?.title ?? Self.appName(for: id), isRunning: iconsByID[id] != nil)
            }
        }
        alwaysHidden = rows(current.alwaysHidden, base.alwaysHidden)
        hidden = rows(current.hidden, base.hidden)
        shown = rows(current.shown, base.shown)
        underNotch = Set(snapshot.iconsUnderNotch.map(\.id))
    }

    /// Moves the row to the right end of another section's list, next to that section's divider.
    func move(_ row: MenuBarLayoutRow, to section: MenuBarSection) {
        alwaysHidden.removeAll { $0 == row }
        hidden.removeAll { $0 == row }
        shown.removeAll { $0 == row }
        switch section {
        case .alwaysHidden: alwaysHidden.append(row)
        case .hidden: hidden.append(row)
        case .shown: shown.insert(row, at: 0)
        }
    }

    func removeMissing() {
        alwaysHidden.removeAll { !$0.isRunning }
        hidden.removeAll { !$0.isRunning }
        shown.removeAll { !$0.isRunning }
    }

    /// "Stats" for "eu.exelban.Stats", when the app is installed.
    private static func appName(for id: String) -> String {
        let bundleID = MenuBarLayoutRow(id: id, title: "", isRunning: false).bundleID
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
