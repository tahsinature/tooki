import Foundation

/// How Tooki's divider looks while hidden icons are showing. A collapsed divider is never visible.
public enum MenuBarDividerStyle: String, Codable, CaseIterable, Sendable {
    case line
    case chevron
    case invisible
}

/// Where the Thaw Bar opens below the menu bar.
public enum ThawBarLocation: String, Codable, CaseIterable, Sendable {
    case underMouse
    case underDivider
    case rightAligned
}

public enum ThawBarStyle: String, Codable, CaseIterable, Sendable {
    /// Translucent, like a menu.
    case material
    /// Opaque window background.
    case solid
}

/// A color drawn behind the menu bar, which the menu bar's own blur then softens.
public struct MenuBarTint: Codable, Equatable, Sendable {
    public var enabled = false
    /// "#RRGGBB".
    public var color = "#1E90FF"
    public var opacity = 0.25

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarTint()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        color = try container.decode(.color, default: defaults.color)
        opacity = try container.decode(.opacity, default: defaults.opacity)
    }
}

/// Red, green and blue from 0 to 1, read from and written as "#RRGGBB".
public struct RGBColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    public var hex: String {
        func byte(_ component: Double) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
