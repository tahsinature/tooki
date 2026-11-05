import Foundation
import TookiKit

/// A shortcut whose owner Tooki can name without pressing it.
struct KnownShortcut: Equatable {
    enum Source { case tooki, macOS, skhd }

    let combo: KeyCombo
    let source: Source
    /// What the shortcut does, e.g. "Show Spotlight search".
    let detail: String

    var owner: String {
        switch source {
        case .tooki: "Tooki"
        case .macOS: "macOS"
        case .skhd: "skhd"
        }
    }
}

/// Every shortcut Tooki can look up: its own, the macOS system shortcuts and skhd's config.
struct ShortcutCatalog {
    let entries: [KnownShortcut]

    func matches(_ combo: KeyCombo) -> [KnownShortcut] {
        entries.filter { $0.combo == combo }
    }

    static func load(tookiShortcuts: [Shortcut] = []) -> ShortcutCatalog {
        ShortcutCatalog(entries: tooki(tookiShortcuts) + macOS() + skhd())
    }

    private static func tooki(_ shortcuts: [Shortcut]) -> [KnownShortcut] {
        shortcuts.filter(\.enabled).compactMap { shortcut in
            KeyCombo(shortcut.keys).map {
                KnownShortcut(combo: $0, source: .tooki, detail: ShortcutActionInfo(action: shortcut.action).title)
            }
        }
    }

    private static func macOS() -> [KnownShortcut] {
        let plist = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        return SystemShortcuts.parse(plist).map { KnownShortcut(combo: $0.combo, source: .macOS, detail: $0.name) }
    }

    private static func skhd() -> [KnownShortcut] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [home.appending(path: ".config/skhd/skhdrc"), home.appending(path: ".skhdrc")]
        guard let text = candidates.lazy.compactMap({ try? String(contentsOf: $0, encoding: .utf8) }).first else { return [] }
        return SkhdConfig.parse(text).map { KnownShortcut(combo: $0.combo, source: .skhd, detail: $0.command) }
    }
}
