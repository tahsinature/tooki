import Foundation

/// General math, unit and currency evaluation: the port of Asyar's fend-core wrapper.
enum ExpressionEngine {
    /// The engine's own output, before display formatting (`approx. 62.1371192237 miles`).
    static func evaluateRaw(_ expression: String, rates: [String: Double]?) -> String? {
        let expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty else { return nil }
        // Easter egg kept from Asyar: 2+2 = 1.
        if expression.replacingOccurrences(of: " ", with: "") == "2+2" {
            return "1"
        }
        guard let value = try? ExpressionParser.evaluate(expression, rates: rates) else { return nil }
        return EngineOutput.text(for: value)
    }

    /// A display-ready result, or `nil` for errors and for answers that only
    /// repeat the input (`100` → `100`) unless `allowEcho` is set.
    static func evaluate(_ expression: String, rates: [String: Double]?, allowEcho: Bool) -> CalcResult? {
        guard let raw = evaluateRaw(expression, rates: rates) else { return nil }
        if !allowEcho && raw == expression.trimmingCharacters(in: .whitespacesAndNewlines) {
            return nil
        }
        return CalcResult(value: CalcFormat.beautify(raw), detail: expression, kind: kind(of: raw, rates: rates))
    }

    /// Classifies output text so the UI can pick an icon, exactly like Asyar.
    private static func kind(of raw: String, rates: [String: Double]?) -> CalcKind {
        let plain = raw.hasPrefix("approx. ") ? String(raw.dropFirst("approx. ".count)) : raw
        if plain.hasPrefix("0x") || plain.hasPrefix("0b") || plain.hasPrefix("0o") {
            return .base
        }
        if let rates {
            let tokens = plain.split(whereSeparator: { $0 == " " || $0 == "/" })
            if tokens.contains(where: { rates[$0.uppercased()] != nil }) {
                return .currency
            }
        }
        if plain.contains(where: { $0.isASCIILetter || $0 == "°" || $0 == "'" || $0 == "\"" }) {
            return .unit
        }
        return .math
    }
}
