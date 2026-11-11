import Foundation

/// Natural-language calculator, ported from Asyar's `asyar-calculator` crate.
///
/// Specialized handlers run first, cheapest and most specific first; the
/// general expression engine runs last.
public enum Calculator {
    /// The answer to a launcher query, or `nil` when the query isn't a calculation.
    public static func evaluate(_ query: String, context: CalculatorContext) -> CalcResult? {
        let canonical = NumberNotation.canonicalize(query, from: context.numberFormat)
        guard var result = evaluateCanonical(canonical, context: context) else { return nil }
        result.value = NumberNotation.localize(result.value, to: context.numberFormat)
        result.detail = NumberNotation.localize(result.detail, to: context.numberFormat)
        return result
    }

    private static func evaluateCanonical(_ query: String, context: CalculatorContext) -> CalcResult? {
        guard InputGate.shouldAttempt(query) else { return nil }
        let normalized = Normalizer.normalize(query)
        guard !normalized.isEmpty else { return nil }
        if let result = evaluateSpecialized(normalized, context: context) {
            return result
        }
        if let inner = Timespan.innerExpression(normalized) {
            return evaluateTimespan(inner, rates: context.rates)
        }
        return CurrencyPhrases.implicitConversion(normalized, context: context)
            ?? CurrencyPhrases.rateConversion(normalized, context: context)
            ?? evaluateExpression(normalized, context: context)
    }

    private static func evaluateSpecialized(_ query: String, context: CalculatorContext) -> CalcResult? {
        ColorConversion.evaluate(query)
            ?? BaseConversion.evaluate(query)
            ?? PercentPhrases.evaluate(query)
            ?? RatioPhrase.evaluate(query)
            ?? CookingConversion.evaluate(query)
            ?? PixelConversion.evaluate(query)
            ?? DatePhrases.evaluate(query, today: context.today)
            ?? WorldClockPhrases.evaluate(query, now: context.now, localZone: WorldZone(context.timeZone))
    }

    /// `145 min to timespan` → `2 h 25 min`.
    private static func evaluateTimespan(_ inner: String, rates: [String: Double]?) -> CalcResult? {
        guard let raw = ExpressionEngine.evaluateRaw("(\(inner)) to seconds", rates: rates),
              let firstWord = raw.split(separator: " ").first,
              let seconds = Double(firstWord) else { return nil }
        return CalcResult(value: Timespan.format(seconds: seconds), detail: inner, kind: .unit)
    }

    /// Evaluates the query, retrying without trailing operators so a
    /// half-typed `12 * 3 +` still shows `36`.
    private static func evaluateExpression(_ query: String, context: CalculatorContext) -> CalcResult? {
        let incompleteTail: Set<Character> = [" ", "+", "-", "*", "/", "^", "(", ",", "."]
        var attempt = Substring(query)
        for _ in 0..<3 {
            let allowEcho = attempt != query
            if let result = ExpressionEngine.evaluate(String(attempt), rates: context.rates, allowEcho: allowEcho) {
                return result.kind == .currency ? CurrencyPhrases.withRatesAge(result, context: context) : result
            }
            var trimmed = attempt
            while let last = trimmed.last, incompleteTail.contains(last) {
                trimmed.removeLast()
            }
            if trimmed == attempt || trimmed.isEmpty { break }
            attempt = trimmed
        }
        return nil
    }
}
