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

/// The editable Shown and Hidden lists, ordered left to right.
@MainActor
@Observable
final class MenuBarLayoutEditorModel {
    var shown: [MenuBarLayoutRow] = []
    var hidden: [MenuBarLayoutRow] = []
    private(set) var underNotch: Set<String> = []

    var layout: MenuBarLayout {
        MenuBarLayout(shown: shown.map(\.id), hidden: hidden.map(\.id))
    }

    /// Shows the saved layout, adding icons it doesn't know yet where they currently are.
    /// With no saved layout, or `fromMenuBar`, shows the menu bar as it is now.
    func load(saved: MenuBarLayout?, separatorFrame: CGRect?, fromMenuBar: Bool = false) async {
        let snapshot = await MenuBarSnapshot.capture(separatorFrame: separatorFrame)
        let current = snapshot.layout
        let base = fromMenuBar ? current : saved ?? current
        let known = Set(base.shown + base.hidden)
        let iconsByID = Dictionary(snapshot.icons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func rows(_ ids: [String]) -> [MenuBarLayoutRow] {
            ids.map { id in
                MenuBarLayoutRow(id: id, title: iconsByID[id]?.title ?? Self.appName(for: id), isRunning: iconsByID[id] != nil)
            }
        }
        shown = rows(current.shown.filter { !known.contains($0) } + base.shown)
        hidden = rows(current.hidden.filter { !known.contains($0) } + base.hidden)
        underNotch = Set(snapshot.iconsUnderNotch.map(\.id))
    }

    func toggleHidden(_ row: MenuBarLayoutRow) {
        if let index = shown.firstIndex(of: row) {
            hidden.append(shown.remove(at: index))
        } else if let index = hidden.firstIndex(of: row) {
            shown.insert(hidden.remove(at: index), at: 0)
        }
    }

    func removeMissing() {
        shown.removeAll { !$0.isRunning }
        hidden.removeAll { !$0.isRunning }
    }

    /// "Stats" for "eu.exelban.Stats", when the app is installed.
    private static func appName(for id: String) -> String {
        let bundleID = MenuBarLayoutRow(id: id, title: "", isRunning: false).bundleID
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
