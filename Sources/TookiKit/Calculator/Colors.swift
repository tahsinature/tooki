import Foundation

/// Color format conversions: hex ↔ rgb ↔ hsl.
enum ColorConversion {
    private enum Format: CaseIterable {
        case hex, rgb, hsl
    }

    private struct RGB {
        let red: Int, green: Int, blue: Int
    }

    private static let target = RegexPattern(#"(?i)^(.+?)\s+(?:to|in|as)\s+(hex|rgb|hsl)$"#)
    private static let hex = RegexPattern(#"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$"#)
    private static let rgb = RegexPattern(#"(?i)^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$"#)
    private static let hsl = RegexPattern(#"(?i)^hsl\(\s*(\d{1,3}(?:\.\d+)?)\s*,\s*(\d{1,3}(?:\.\d+)?)%\s*,\s*(\d{1,3}(?:\.\d+)?)%\s*\)$"#)

    /// Accepts `#ff8800`, `#f80`, `rgb(255, 136, 0)` or `hsl(32, 100%, 50%)`,
    /// each optionally followed by `to hex|rgb|hsl`.
    static func evaluate(_ query: String) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var colorText = text
        var requestedFormat: Format?
        if let match = target.firstMatch(in: text) {
            colorText = match.text(1)
            requestedFormat = switch match.text(2).lowercased() {
            case "hex": .hex
            case "rgb": .rgb
            default: .hsl
            }
        }

        guard let (color, sourceFormat) = parse(colorText) else { return nil }
        // Hex shows rgb by default; rgb and hsl show hex.
        let outputFormat = requestedFormat ?? (sourceFormat == .hex ? .rgb : .hex)
        let detail = Format.allCases
            .filter { $0 != outputFormat }
            .map { render(color, as: $0) }
            .joined(separator: " · ")
        return CalcResult(value: render(color, as: outputFormat), detail: detail, kind: .color)
    }

    private static func parse(_ text: String) -> (RGB, Format)? {
        if let match = hex.firstMatch(in: text) {
            var digits = match.text(1)
            if digits.count == 3 {
                digits = String(digits.flatMap { [$0, $0] })
            }
            guard let value = Int(digits, radix: 16) else { return nil }
            return (RGB(red: value >> 16 & 0xFF, green: value >> 8 & 0xFF, blue: value & 0xFF), .hex)
        }
        if let match = rgb.firstMatch(in: text) {
            let channels = (1...3).compactMap { Int(match.text($0)) }.filter { $0 <= 255 }
            guard channels.count == 3 else { return nil }
            return (RGB(red: channels[0], green: channels[1], blue: channels[2]), .rgb)
        }
        if let match = hsl.firstMatch(in: text) {
            guard let hue = Double(match.text(1)), let saturation = Double(match.text(2)), let lightness = Double(match.text(3)),
                  hue < 360, saturation <= 100, lightness <= 100 else { return nil }
            return (rgbFromHSL(hue: hue, saturation: saturation / 100, lightness: lightness / 100), .hsl)
        }
        return nil
    }

    private static func render(_ color: RGB, as format: Format) -> String {
        switch format {
        case .hex:
            return String(format: "#%02X%02X%02X", color.red, color.green, color.blue)
        case .rgb:
            return "rgb(\(color.red), \(color.green), \(color.blue))"
        case .hsl:
            let (hue, saturation, lightness) = hslFromRGB(color)
            return "hsl(\(Int(hue.rounded())), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)"
        }
    }

    private static func hslFromRGB(_ color: RGB) -> (hue: Double, saturation: Double, lightness: Double) {
        let red = Double(color.red) / 255, green = Double(color.green) / 255, blue = Double(color.blue) / 255
        let maximum = max(red, green, blue), minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        guard maximum != minimum else { return (0, 0, lightness) }

        let delta = maximum - minimum
        let saturation = lightness > 0.5 ? delta / (2 - maximum - minimum) : delta / (maximum + minimum)
        let hueSector: Double
        if maximum == red {
            hueSector = positiveRemainder((green - blue) / delta, 6)
        } else if maximum == green {
            hueSector = (blue - red) / delta + 2
        } else {
            hueSector = (red - green) / delta + 4
        }
        return (hueSector * 60, saturation, lightness)
    }

    private static func rgbFromHSL(hue: Double, saturation: Double, lightness: Double) -> RGB {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let secondary = chroma * (1 - abs(positiveRemainder(hue / 60, 2) - 1))
        let (red, green, blue): (Double, Double, Double) = switch hue {
        case ..<60: (chroma, secondary, 0)
        case ..<120: (secondary, chroma, 0)
        case ..<180: (0, chroma, secondary)
        case ..<240: (0, secondary, chroma)
        case ..<300: (secondary, 0, chroma)
        default: (chroma, 0, secondary)
        }
        let lightnessMatch = lightness - chroma / 2
        func byte(_ channel: Double) -> Int {
            Int(min(max(((channel + lightnessMatch) * 255).rounded(), 0), 255))
        }
        return RGB(red: byte(red), green: byte(green), blue: byte(blue))
    }

    /// Euclidean remainder, always in `0..<divisor`.
    private static func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        value - divisor * (value / divisor).rounded(.down)
    }
}
