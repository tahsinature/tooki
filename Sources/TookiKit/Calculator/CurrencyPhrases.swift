import Foundation

/// Currency shortcuts that rewrite the query before handing it to the engine.
enum CurrencyPhrases {
    private static let bareAmount = RegexPattern(#"^(\d[\d,]*(?:\.\d+)?)\s*([A-Z]{3,4})$"#)
    private static let rateUnit = RegexPattern(#"^(.+?/\s*([a-zA-Z]+))\s+(?:in|to)\s+([A-Z]{3,4})$"#)

    /// `50 EUR` alone converts to the preferred currency.
    static func implicitConversion(_ query: String, context: CalculatorContext) -> CalcResult? {
        guard let match = bareAmount.firstMatch(in: query) else { return nil }
        let preferred = context.preferredCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard preferred.utf8.count == 3, match.text(2) != preferred else { return nil }
        let expression = "\(match.text(1)) \(match.text(2)) to \(preferred)"
        return ExpressionEngine.evaluate(expression, rates: context.rates, allowEcho: false)
            .map { withRatesAge($0, context: context) }
    }

    /// `20 USD/hour in EUR` keeps the denominator: `… to EUR/hour`.
    static func rateConversion(_ query: String, context: CalculatorContext) -> CalcResult? {
        guard let match = rateUnit.firstMatch(in: query) else { return nil }
        let expression = "\(match.text(1)) to \(match.text(3))/\(match.text(2))"
        return ExpressionEngine.evaluate(expression, rates: context.rates, allowEcho: false)
            .map { withRatesAge($0, context: context) }
    }

    /// Appends `· rates 2 h old` when the rates' age is known.
    static func withRatesAge(_ result: CalcResult, context: CalculatorContext) -> CalcResult {
        guard let age = context.ratesAge else { return result }
        var result = result
        result.detail += " · rates \(age) old"
        return result
    }
}
