import Foundation

/// Writes engine results the way fend-core does (`1024`, `177.8 cm`,
/// `approx. 62.1371192237 miles`), before `CalcFormat.beautify` groups digits.
enum EngineOutput {
    private static let largestExactInteger = 9_007_199_254_740_992.0

    static func text(for value: ExpressionValue) -> String? {
        switch value {
        case .based(let text):
            return text
        case .quantity(let quantity):
            return text(for: quantity)
        }
    }

    private static func text(for quantity: Quantity) -> String? {
        guard let (number, isApproximate) = number(quantity.displayValue) else { return nil }
        var text = number
        if let unit = quantity.unit {
            let label = unit.label(forFormattedValue: number)
            text += (label == "%" || label == "°") ? label : " " + label
        }
        return isApproximate ? "approx. " + text : text
    }

    /// Up to ten decimals; scientific notation for huge or tiny values.
    /// Binary floating-point noise (`316000.0000000001`) is rounded away first,
    /// since fend computes with exact fractions.
    static func number(_ value: Double) -> (text: String, isApproximate: Bool)? {
        guard value.isFinite else { return nil }
        if value == 0 { return ("0", false) }
        if abs(value) < 1e-15 { return ("0", true) }
        if abs(value) >= 1e21 { return (scientific(value), true) }
        let isBelowPrecisionLimit = abs(value) < largestExactInteger
        let withoutNoise = isBelowPrecisionLimit ? Double(String(format: "%.15g", value)) ?? value : value
        let text = trimmingFractionZeros(String(format: "%.10f", withoutNoise))
        if text == "0" || text == "-0" { return (scientific(value), true) }
        let shown = Double(text) ?? value
        let isApproximate = abs(shown - value) > abs(value) * 1e-14 || !isBelowPrecisionLimit
        return (text, isApproximate)
    }

    /// `1.5e+30` → `1.5e30`.
    private static func scientific(_ value: Double) -> String {
        let parts = String(format: "%.9e", value).split(separator: "e")
        let mantissa = trimmingFractionZeros(String(parts[0]))
        let exponent = Int(parts[1]) ?? 0
        return "\(mantissa)e\(exponent)"
    }

    private static func trimmingFractionZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var trimmed = text
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }
}
