import Foundation

/// `ratio of 384 to 240` → the simplified `8 : 5`.
enum RatioPhrase {
    private static let pattern = RegexPattern(#"(?i)^ratio\s+of\s+(\d+(?:\.\d+)?)\s+to\s+(\d+(?:\.\d+)?)$"#)

    static func evaluate(_ query: String) -> CalcResult? {
        guard let match = pattern.firstMatch(in: query.trimmingCharacters(in: .whitespacesAndNewlines)),
              let left = Double(match.text(1)), let right = Double(match.text(2)),
              left > 0, right > 0 else { return nil }

        // Scale decimals up to whole numbers, using at most 4 decimal places.
        let decimals = min(4, max(decimalPlaces(match.text(1)), decimalPlaces(match.text(2))))
        let scale = pow(10, Double(decimals))
        let scaledLeft = (left * scale).rounded(), scaledRight = (right * scale).rounded()
        guard scaledLeft < 1e18, scaledRight < 1e18 else { return nil }
        let wholeLeft = UInt64(scaledLeft), wholeRight = UInt64(scaledRight)
        let divisor = greatestCommonDivisor(wholeLeft, wholeRight)

        return CalcResult(
            value: "\(wholeLeft / divisor) : \(wholeRight / divisor)",
            detail: "\(perOne(left / right)) : 1",
            kind: .ratio
        )
    }

    private static func perOne(_ quotient: Double) -> String {
        if abs(quotient - quotient.rounded()) < 1e-9 {
            return String(Int64(quotient.rounded()))
        }
        return String(format: "%.4f", quotient).trimmingSuffix("0")
    }

    private static func decimalPlaces(_ text: String) -> Int {
        guard let dot = text.firstIndex(of: ".") else { return 0 }
        return text.distance(from: dot, to: text.endIndex) - 1
    }

    private static func greatestCommonDivisor(_ first: UInt64, _ second: UInt64) -> UInt64 {
        var (a, b) = (first, second)
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return max(a, 1)
    }
}

/// Whole-query based literals (`0xff`) and base conversion requests
/// (`255 to hex`, `12 to binary`, `0x2f to decimal`).
enum BaseConversion {
    private static let literal = RegexPattern(#"^(0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+)$"#)
    private static let toBase = RegexPattern(#"(?i)^(0x[0-9a-f]+|0b[01]+|0o[0-7]+|\d+)\s+(?:to|in|as)\s+(hex|hexadecimal|binary|bin|octal|oct|decimal|dec)$"#)

    static func evaluate(_ query: String) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if literal.matches(text) {
            guard let value = parseLiteral(text) else { return nil }
            return CalcResult(value: CalcFormat.groupThousands(String(value)), detail: allBases(value), kind: .base)
        }

        if let match = toBase.firstMatch(in: text) {
            guard let value = parseLiteral(match.text(1)) else { return nil }
            let rendered = switch match.text(2).lowercased() {
            case "hex", "hexadecimal": "0x" + String(value, radix: 16, uppercase: true)
            case "binary", "bin": "0b" + String(value, radix: 2)
            case "octal", "oct": "0o" + String(value, radix: 8)
            default: CalcFormat.groupThousands(String(value))
            }
            return CalcResult(value: rendered, detail: allBases(value), kind: .base)
        }

        return nil
    }

    /// `0xff`, `0b1010`, `0o755` or plain decimal digits.
    static func parseLiteral(_ text: String) -> UInt64? {
        let lowered = text.lowercased()
        let radixes: [(prefix: String, radix: Int)] = [("0x", 16), ("0b", 2), ("0o", 8)]
        for (prefix, radix) in radixes where lowered.hasPrefix(prefix) {
            return UInt64(lowered.dropFirst(2), radix: radix)
        }
        return UInt64(text)
    }

    private static func allBases(_ value: UInt64) -> String {
        "0b\(String(value, radix: 2)) · 0o\(String(value, radix: 8)) · 0x\(String(value, radix: 16, uppercase: true))"
    }
}

/// Design-size conversions: `2 inches in px at 72 ppi` → `144 px`,
/// `144 px in inches at 72 ppi` → `2 in`.
enum PixelConversion {
    private static let toPixels = RegexPattern(#"(?i)^(\d+(?:\.\d+)?)\s*(inches|inch|in|cm|mm|points|point|pt)\s+(?:in|to|as)\s+(?:px|pixels?)\s+at\s+(\d+(?:\.\d+)?)\s*(?:ppi|dpi)$"#)
    private static let fromPixels = RegexPattern(#"(?i)^(\d+(?:\.\d+)?)\s*(?:px|pixels?)\s+(?:in|to|as)\s+(inches|inch|in|cm|mm|points|point|pt)\s+at\s+(\d+(?:\.\d+)?)\s*(?:ppi|dpi)$"#)

    static func evaluate(_ query: String) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = toPixels.firstMatch(in: text) {
            guard let amount = Double(match.text(1)), let unit = inchUnit(match.text(2)),
                  let ppi = Double(match.text(3)) else { return nil }
            let pixels = amount * unit.inches * ppi
            return CalcResult(value: "\(CalcFormat.number(pixels)) px", detail: "at \(CalcFormat.number(ppi)) ppi", kind: .unit)
        }

        if let match = fromPixels.firstMatch(in: text) {
            guard let pixels = Double(match.text(1)), let unit = inchUnit(match.text(2)),
                  let ppi = Double(match.text(3)), ppi != 0 else { return nil }
            let amount = pixels / ppi / unit.inches
            return CalcResult(value: "\(CalcFormat.number(amount)) \(unit.label)", detail: "at \(CalcFormat.number(ppi)) ppi", kind: .unit)
        }

        return nil
    }

    /// Size of one unit in inches, and its short label.
    private static func inchUnit(_ name: String) -> (inches: Double, label: String)? {
        switch name.lowercased() {
        case "in", "inch", "inches": (1, "in")
        case "cm": (1 / 2.54, "cm")
        case "mm": (1 / 25.4, "mm")
        case "pt", "point", "points": (1 / 72, "pt")
        default: nil
        }
    }
}

/// `145 min to timespan` → `2 h 25 min`.
enum Timespan {
    private static let pattern = RegexPattern(#"(?i)^(.+?)\s+(?:to|in|as)\s+(?:timespan|hours?\s+and\s+min(?:ute)?s?)$"#)

    /// The expression to evaluate in seconds, when the query asks for a timespan.
    static func innerExpression(_ query: String) -> String? {
        pattern.firstMatch(in: query.trimmingCharacters(in: .whitespacesAndNewlines))?.text(1)
    }

    /// `8700` → `2 h 25 min`. Shows the two largest non-zero units.
    static func format(seconds: Double) -> String {
        let magnitude = abs(seconds.rounded())
        guard !magnitude.isNaN, magnitude >= 1 else { return "0 s" }
        var remaining = magnitude < 1.8e19 ? UInt64(magnitude) : UInt64.max
        let units: [(size: UInt64, label: String)] = [(86_400, "d"), (3600, "h"), (60, "min"), (1, "s")]
        var parts: [String] = []
        for unit in units where parts.count < 2 {
            let count = remaining / unit.size
            remaining %= unit.size
            if count > 0 {
                parts.append("\(count) \(unit.label)")
            }
        }
        return parts.joined(separator: " ")
    }
}
