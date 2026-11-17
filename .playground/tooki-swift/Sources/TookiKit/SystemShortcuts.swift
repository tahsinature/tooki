import Foundation

/// macOS keyboard shortcuts from System Settings > Keyboard > Keyboard Shortcuts,
/// stored in the `com.apple.symbolichotkeys` preferences under `AppleSymbolicHotKeys`.
public enum SystemShortcuts {
    public struct Entry: Equatable, Sendable {
        public let combo: KeyCombo
        public let name: String
    }

    /// The plist only lists shortcuts the user changed, so known defaults fill the gaps.
    public static func parse(_ symbolicHotKeys: [String: Any]) -> [Entry] {
        var combos = defaults
        for (key, value) in symbolicHotKeys {
            guard let id = Int(key), let entry = value as? [String: Any] else { continue }
            let isEnabled = (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1)
            let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int]
            if !isEnabled {
                combos[id] = nil
            } else if let parameters, parameters.count == 3, let combo = combo(from: parameters) {
                combos[id] = combo
            }
        }
        return combos.compactMap { id, combo in
            names[id].map { Entry(combo: combo, name: $0) }
        }
        .sorted { $0.name < $1.name }
    }

    /// `parameters` is `[character, key code, modifier flags]`.
    private static func combo(from parameters: [Int]) -> KeyCombo? {
        let flags = parameters[2]
        var modifiers: KeyCombo.Modifiers = []
        if flags & (1 << 17) != 0 { modifiers.insert(.shift) }
        if flags & (1 << 18) != 0 { modifiers.insert(.control) }
        if flags & (1 << 19) != 0 { modifiers.insert(.option) }
        if flags & (1 << 20) != 0 { modifiers.insert(.command) }
        guard let keyCode = UInt16(exactly: parameters[1]) else { return nil }
        return KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    private static let names: [Int: String] = [
        27: "Move focus to next window",
        28: "Save picture of screen as a file",
        29: "Copy picture of screen to the clipboard",
        30: "Save picture of selected area as a file",
        31: "Copy picture of selected area to the clipboard",
        32: "Mission Control",
        33: "Application windows",
        36: "Show Desktop",
        60: "Select the previous input source",
        61: "Select next source in Input menu",
        64: "Show Spotlight search",
        65: "Show Finder search window",
        79: "Move left a space",
        81: "Move right a space",
        118: "Switch to Desktop 1",
        119: "Switch to Desktop 2",
        120: "Switch to Desktop 3",
        121: "Switch to Desktop 4",
        184: "Screenshot and recording options",
    ]

    private static let defaults: [Int: KeyCombo] = [
        27: "cmd+`", 28: "shift+cmd+3", 29: "ctrl+shift+cmd+3", 30: "shift+cmd+4", 31: "ctrl+shift+cmd+4",
        32: "ctrl+up", 33: "ctrl+down", 60: "ctrl+space", 61: "ctrl+opt+space",
        64: "cmd+space", 65: "opt+cmd+space", 79: "ctrl+left", 81: "ctrl+right", 184: "shift+cmd+5",
    ].compactMapValues { KeyCombo($0) }
}
