/// A key plus modifiers, written in `config.json` as text like `hyper+s` or `ctrl+opt+k`.
public struct KeyCombo: Equatable, Hashable, Sendable, CustomStringConvertible {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
        /// What the Hyper key (Caps Lock) stands for.
        public static let hyper: Modifiers = [.control, .option, .shift, .command]

        /// In the standard macOS order: ⌃⌥⇧⌘.
        public var symbols: [String] {
            KeyCombo.modifierOrder.filter { contains($0.modifier) }.map(\.symbol)
        }
    }

    public let modifiers: Modifiers
    /// The normalized key name, as used by `KeyCode.forKey`.
    public let key: String

    public var keyCode: UInt16 { KeyCode.forKey(key) ?? 0 }

    /// Combos need a modifier unless the key is a function key.
    public init?(keyCode: UInt16, modifiers: Modifiers) {
        guard let key = KeyCode.name(for: keyCode) else { return nil }
        guard !modifiers.isEmpty || KeyCode.isFunctionKey(keyCode) else { return nil }
        self.key = key
        self.modifiers = modifiers
    }

    public init?(_ text: String) {
        var tokens = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let keyToken = tokens.popLast(), let keyCode = KeyCode.forKey(keyToken) else { return nil }
        var modifiers: Modifiers = []
        for token in tokens {
            guard let modifier = Self.modifierNames[token] else { return nil }
            modifiers.formUnion(modifier)
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    /// The text stored in `config.json`.
    public var description: String {
        let names = modifiers == .hyper ? ["hyper"] : Self.modifierOrder.filter { modifiers.contains($0.modifier) }.map(\.name)
        return (names + [key]).joined(separator: "+")
    }

    /// One symbol per key cap, e.g. `["⌃", "⌥", "⇧", "⌘", "S"]`.
    public var symbols: [String] {
        modifiers.symbols + [Self.symbol(forKey: key)]
    }

    /// Common macOS shortcuts that would break everyday editing if taken over.
    public var isReservedBySystem: Bool {
        Self.reserved.contains(description)
    }

    private static let modifierOrder: [(modifier: Modifiers, name: String, symbol: String)] = [
        (.control, "ctrl", "⌃"), (.option, "opt", "⌥"), (.shift, "shift", "⇧"), (.command, "cmd", "⌘"),
    ]

    private static let modifierNames: [String: Modifiers] = [
        "ctrl": .control, "control": .control,
        "opt": .option, "option": .option, "alt": .option,
        "shift": .shift,
        "cmd": .command, "command": .command,
        "hyper": .hyper,
    ]

    /// ⌘Space isn't here: Spotlight's shortcut can be turned off, and the live macOS
    /// shortcut check warns when it's still on.
    private static let reserved: Set<String> = [
        "cmd+q", "cmd+w", "cmd+c", "cmd+v", "cmd+x", "cmd+z", "cmd+a", "cmd+s", "cmd+n", "cmd+t",
        "cmd+h", "cmd+m", "cmd+tab", "cmd+,", "shift+cmd+z",
    ]

    private static func symbol(forKey key: String) -> String {
        switch key {
        case "space": "Space"
        case "return": "↩"
        case "tab": "⇥"
        case "escape": "⎋"
        case "left": "←"
        case "right": "→"
        case "up": "↑"
        case "down": "↓"
        default: key.uppercased()
        }
    }
}
