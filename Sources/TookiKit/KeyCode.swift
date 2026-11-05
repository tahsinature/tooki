/// macOS virtual key codes (ANSI layout) used by Tooki.
public enum KeyCode {
    public static let returnKey: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let space: UInt16 = 49
    public static let delete: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let f18: UInt16 = 79
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
    public static let v: UInt16 = 9

    private static let functionKeys: [String: UInt16] = [
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]

    private static let named: [String: UInt16] = [
        "space": space, "return": returnKey, "tab": tab, "escape": escape,
        "left": leftArrow, "right": rightArrow, "up": upArrow, "down": downArrow,
    ]

    private static let byCharacter: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50,
    ]

    public static func forKey(_ key: String) -> UInt16? {
        switch key.lowercased() {
        case "space": space
        case "return", "enter": returnKey
        case "tab": tab
        case "escape", "esc": escape
        case "left": leftArrow
        case "right": rightArrow
        case "up": upArrow
        case "down": downArrow
        default: functionKeys[key.lowercased()] ?? (key.count == 1 ? byCharacter[Character(key.lowercased())] : nil)
        }
    }

    /// The name `forKey` accepts for a key code, or `nil` for keys Tooki does not support.
    public static func name(for keyCode: UInt16) -> String? {
        let all = named.merging(functionKeys) { first, _ in first }
            .merging(byCharacter.map { (String($0.key), $0.value) }) { first, _ in first }
        return all.first { $0.value == keyCode }?.key
    }

    public static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        functionKeys.values.contains(keyCode)
    }
}
