import Foundation

/// Currency codes and names, resolved against the injected rates table
/// (units of each currency per one US dollar).
enum CurrencyUnits {
    private static let names = ["dollar": "USD", "dollars": "USD", "euro": "EUR", "euros": "EUR", "yen": "JPY"]

    static func resolve(_ word: String, rates: [String: Double]?) -> ResolvedUnit? {
        guard let rates else { return nil }
        let code = names[word.lowercased()] ?? word
        guard code == code.uppercased(), let rate = rates[code], rate > 0 else { return nil }
        return ResolvedUnit(
            display: DisplayUnit(singular: code, factor: dollarsPerUnit(code: code, rate: rate)),
            dimension: .currency
        )
    }

    /// Like Asyar, crypto prices are rounded to 8 decimals so `1 BTC` at a rate
    /// of 1/80000 is exactly 80,000 USD rather than 79,999.99999999999.
    static func dollarsPerUnit(code: String, rate: Double) -> Double {
        let price = 1 / rate
        guard !Normalizer.isoCurrencyCodes.contains(code) else { return price }
        return Double(String(format: "%.8f", price)) ?? price
    }
}
