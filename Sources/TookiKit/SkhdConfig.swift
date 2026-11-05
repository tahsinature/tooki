import Foundation

/// Reads hotkeys from an skhd config file (`skhdrc`).
/// Lines look like `alt + shift - t : command` or `cmd - 0x12 : command`.
public enum SkhdConfig {
    public struct Binding: Equatable, Sendable {
        public let combo: KeyCombo
        public let command: String
    }

    /// Lines skhd uses that Tooki can't represent (modes, `fn`, unsupported keys) are skipped.
    public static func parse(_ text: String) -> [Binding] {
        var bindings: [Binding] = []
        var continuesPreviousLine = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            defer { continuesPreviousLine = line.hasSuffix("\\") }
            guard !continuesPreviousLine, !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(".") else { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let command = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if let combo = combo(from: String(line[..<colon])) {
                bindings.append(Binding(combo: combo, command: command))
            }
        }
        return bindings
    }

    private static func combo(from hotkey: String) -> KeyCombo? {
        var text = hotkey
        // Drop a mode prefix (`mode < ...`) and the passthrough marker (`->`).
        if let modeEnd = text.lastIndex(of: "<") { text = String(text[text.index(after: modeEnd)...]) }
        text = text.replacingOccurrences(of: "->", with: "").trimmingCharacters(in: .whitespaces)

        let parts = text.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        let keyText = parts.count == 2 ? parts[1] : parts[0]
        var modifiers: KeyCombo.Modifiers = []
        if parts.count == 2 {
            for name in parts[0].split(separator: "+") {
                guard let modifier = modifierNames[name.trimmingCharacters(in: .whitespaces)] else { return nil }
                modifiers.formUnion(modifier)
            }
        }
        guard let keyCode = keyCode(from: keyText) else { return nil }
        return KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    private static func keyCode(from text: String) -> UInt16? {
        if text.hasPrefix("0x") { return UInt16(text.dropFirst(2), radix: 16) }
        return KeyCode.forKey(text)
    }

    private static let modifierNames: [String: KeyCombo.Modifiers] = [
        "alt": .option, "lalt": .option, "ralt": .option,
        "shift": .shift, "lshift": .shift, "rshift": .shift,
        "cmd": .command, "lcmd": .command, "rcmd": .command,
        "ctrl": .control, "lctrl": .control, "rctrl": .control,
        "hyper": .hyper, "meh": [.control, .option, .shift],
    ]
}
