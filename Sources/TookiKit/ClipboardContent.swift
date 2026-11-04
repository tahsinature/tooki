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
