import Foundation

/// What a clipboard item contains, used for icons, previews and the type filter.
public enum ClipboardContentType: String, CaseIterable, Sendable {
    case text
    case link
    case color
    case image
    case file

    public var label: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .color: "Color"
        case .image: "Image"
        case .file: "File"
        }
    }
}

/// A colour written as #RGB, #RRGGBB or #RRGGBBAA. Components are 0...1.
public struct HexColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        var hex = String(trimmed.dropFirst())
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        if hex.count == 6 { hex += "FF" }
        guard hex.count == 8, hex.allSatisfy(\.isHexDigit), let value = UInt32(hex, radix: 16) else { return nil }
        red = Double((value >> 24) & 0xFF) / 255
        green = Double((value >> 16) & 0xFF) / 255
        blue = Double((value >> 8) & 0xFF) / 255
        alpha = Double(value & 0xFF) / 255
    }

    /// For example "rgb(255, 99, 99)".
    public var rgbDescription: String {
        "rgb(\(Int((red * 255).rounded())), \(Int((green * 255).rounded())), \(Int((blue * 255).rounded())))"
    }

    /// For example "hsl(0, 100%, 69%)".
    public var hslDescription: String {
        let high = max(red, green, blue), low = min(red, green, blue)
        let lightness = (high + low) / 2
        let delta = high - low
        var hue = 0.0, saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            hue = switch high {
            case red: (green - blue) / delta
            case green: (blue - red) / delta + 2
            default: (red - green) / delta + 4
            }
            hue = (hue * 60).truncatingRemainder(dividingBy: 360)
            if hue < 0 { hue += 360 }
        }
        return "hsl(\(Int(hue.rounded())), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)"
    }
}

extension ClipboardItem {
    public var contentType: ClipboardContentType {
        if image != nil { return .image }
        if files != nil { return .file }
        if HexColor(text) != nil { return .color }
        if isLink { return .link }
        return .text
    }

    /// A single URL such as https://…, slack://… or mailto:…, with no spaces.
    private var isLink: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^([a-zA-Z][a-zA-Z0-9+.-]*://|mailto:|tel:)\S+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
