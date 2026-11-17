import Foundation

/// Soulver-style percentage phrases: discounts, tips, percent change and `X ± Y%`.
enum PercentPhrases {
    private static let number = #"(\d[\d,]*(?:\.\d+)?[kmbKMB]?)"#
    private static let percentOf = RegexPattern(#"(?i)^\#(number)\s*%\s*of\s+\#(number)$"#)
    private static let percentOff = RegexPattern(#"(?i)^\#(number)\s*%\s*off\s+(?:of\s+)?\#(number)$"#)
    private static let tipOn = RegexPattern(#"(?i)^\#(number)\s*%\s*tip\s+on\s+\#(number)$"#)
    private static let plusMinus = RegexPattern(#"^\#(number)\s*([+\-])\s*\#(number)\s*%$"#)
    private static let whatPercent = RegexPattern(#"(?i)^\#(number)\s+is\s+what\s+(?:%|percent)\s+of\s+\#(number)$"#)
    private static let change = RegexPattern(#"(?i)^%\s*change\s+from\s+\#(number)\s+to\s+\#(number)$"#)
    private static let increaseDecrease = RegexPattern(#"(?i)^(increase|decrease)\s+\#(number)\s+by\s+\#(number)\s*%$"#)

    /// Evaluates a percentage phrase, or returns `nil` when the query isn't one.
    static func evaluate(_ query: String) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = percentOf.firstMatch(in: text) {
            guard let percent = parse(match.text(1)), let base = parse(match.text(2)) else { return nil }
            return CalcResult(
                value: CalcFormat.number(base * percent / 100),
                detail: "\(CalcFormat.number(percent))% of \(CalcFormat.number(base))",
                kind: .percent
            )
        }

        if let match = percentOff.firstMatch(in: text) {
            guard let percent = parse(match.text(1)), let base = parse(match.text(2)) else { return nil }
            let saved = base * percent / 100
            return CalcResult(
                value: CalcFormat.number(base - saved),
                detail: "You save \(CalcFormat.number(saved))",
                kind: .percent
            )
        }

        if let match = tipOn.firstMatch(in: text) {
            guard let percent = parse(match.text(1)), let base = parse(match.text(2)) else { return nil }
            let tip = base * percent / 100
            return CalcResult(value: CalcFormat.money(base + tip), detail: "Tip: \(CalcFormat.money(tip))", kind: .percent)
        }

        if let match = plusMinus.firstMatch(in: text) {
            guard let base = parse(match.text(1)), let percent = parse(match.text(3)) else { return nil }
            let delta = base * percent / 100
            let value = match.text(2) == "+" ? base + delta : base - delta
            return CalcResult(
                value: CalcFormat.number(value),
                detail: "\(CalcFormat.number(percent))% of \(CalcFormat.number(base)) = \(CalcFormat.number(delta))",
                kind: .percent
            )
        }

        if let match = whatPercent.firstMatch(in: text) {
            guard let part = parse(match.text(1)), let whole = parse(match.text(2)), whole != 0 else { return nil }
            return CalcResult(
                value: "\(CalcFormat.number(part / whole * 100))%",
                detail: "\(CalcFormat.number(part)) of \(CalcFormat.number(whole))",
                kind: .percent
            )
        }

        if let match = change.firstMatch(in: text) {
            guard let from = parse(match.text(1)), let to = parse(match.text(2)), from != 0 else { return nil }
            return CalcResult(
                value: signedPercent((to - from) / from * 100),
                detail: "from \(CalcFormat.number(from)) to \(CalcFormat.number(to))",
                kind: .percent
            )
        }

        if let match = increaseDecrease.firstMatch(in: text) {
            guard let base = parse(match.text(2)), let percent = parse(match.text(3)) else { return nil }
            let verb = match.text(1)
            let delta = base * percent / 100
            let value = verb.lowercased() == "increase" ? base + delta : base - delta
            return CalcResult(
                value: CalcFormat.number(value),
                detail: "\(verb) \(CalcFormat.number(base)) by \(CalcFormat.number(percent))%",
                kind: .percent
            )
        }

        return nil
    }

    /// Reads `1,200`, and Soulver-style shorthand: `19m` is 19 million, `1.2k` is 1,200.
    private static func parse(_ text: String) -> Double? {
        var digits = text.replacingOccurrences(of: ",", with: "")
        let factor: Double
        switch digits.last?.lowercased() {
        case "k": factor = 1e3
        case "m": factor = 1e6
        case "b": factor = 1e9
        default: factor = 1
        }
        if factor != 1 {
            digits.removeLast()
        }
        return Double(digits).map { $0 * factor }
    }

    /// Up to 2 decimals with an explicit sign: `+20%`, `-16.67%`.
    private static func signedPercent(_ percent: Double) -> String {
        let rounded = (percent * 100).rounded() / 100
        let sign = rounded >= 0 ? "+" : "-"
        let body = String(format: "%.2f", abs(rounded)).trimmingSuffix("0").trimmingSuffix(".")
        return "\(sign)\(body)%"
    }
}
