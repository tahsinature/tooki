import Foundation

/// Turns loosely typed natural language into expressions the handlers and
/// the expression engine understand.
enum Normalizer {
    /// ISO 4217 codes. A lowercased code is uppercased so the engine sees a currency.
    static let isoCurrencyCodes: Set<String> = [
        "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD", "BDT",
        "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BOV", "BRL", "BSD", "BTN", "BWP", "BYN", "BZD",
        "CAD", "CDF", "CHE", "CHF", "CHW", "CLF", "CLP", "CNY", "COP", "COU", "CRC", "CUC", "CUP",
        "CVE", "CZK", "DJF", "DKK", "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD", "FKP", "GBP",
        "GEL", "GHS", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD", "HNL", "HRK", "HTG", "HUF", "IDR",
        "ILS", "INR", "IQD", "IRR", "ISK", "JMD", "JOD", "JPY", "KES", "KGS", "KHR", "KMF", "KPW",
        "KRW", "KWD", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "LYD", "MAD", "MDL", "MGA",
        "MKD", "MMK", "MNT", "MOP", "MRU", "MUR", "MVR", "MWK", "MXN", "MXV", "MYR", "MZN", "NAD",
        "NGN", "NIO", "NOK", "NPR", "NZD", "OMR", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG",
        "QAR", "RON", "RSD", "RUB", "RWF", "SAR", "SBD", "SCR", "SDG", "SEK", "SGD", "SHP", "SLE",
        "SLL", "SOS", "SRD", "SSP", "STN", "SVC", "SYP", "SZL", "THB", "TJS", "TMT", "TND", "TOP",
        "TRY", "TTD", "TWD", "TZS", "UAH", "UGX", "USD", "USN", "UYI", "UYU", "UYW", "UZS", "VED",
        "VES", "VND", "VUV", "WST", "XAF", "XAG", "XAU", "XCD", "XDR", "XOF", "XPD", "XPF", "XPT",
        "YER", "ZAR", "ZMW", "ZWL",
    ]

    /// Crypto tickers treated as money. `SOL` is deliberately absent: it
    /// collides with the Peruvian sol and the Mars solar day.
    static let cryptoCodes: Set<String> = [
        "BTC", "ETH", "BNB", "XRP", "ADA", "DOGE", "LTC", "DOT", "TRX", "LINK", "BCH", "XLM", "USDT", "USDC",
    ]

    static func isCurrencyCode(_ token: String) -> Bool {
        let upper = token.uppercased()
        return isoCurrencyCodes.contains(upper) || cryptoCodes.contains(upper)
    }

    private static let symbolCodes: [String: String] = ["$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY"]

    private static let questionPrefix = RegexPattern(#"(?i)^(?:what\s+is|what's|whats|how\s+much\s+is|convert|calculate|calc)\s+"#)
    private static let squareRoot = RegexPattern(#"(?i)\bsquare\s+root\s+of\s+(.+)$"#)
    private static let cubeRoot = RegexPattern(#"(?i)\bcube\s+root\s+of\s+(.+)$"#)
    private static let toThePowerOf = RegexPattern(#"(?i)\s+to\s+the\s+power\s+of\s+"#)
    private static let powerWord = RegexPattern(#"(?i)(\d+(?:\.\d+)?)\s+power\s+(\d+(?:\.\d+)?)"#)
    private static let times = RegexPattern(#"(?i)\s+times\s+"#)
    private static let dividedBy = RegexPattern(#"(?i)\s+divided\s+by\s+"#)
    private static let plus = RegexPattern(#"(?i)\s+plus\s+"#)
    private static let minus = RegexPattern(#"(?i)\s+minus\s+"#)
    private static let squared = RegexPattern(#"(?i)(\d+(?:\.\d+)?)\s+squared\b"#)
    private static let cubed = RegexPattern(#"(?i)(\d+(?:\.\d+)?)\s+cubed\b"#)
    private static let halfOf = RegexPattern(#"(?i)\bhalf\s+of\s+(.+)$"#)
    private static let percentWord = RegexPattern(#"(?i)(\d+(?:\.\d+)?)\s+percent\b"#)
    private static let symbolAmount = RegexPattern(#"([$€£¥])\s*(\d[\d,]*(?:\.\d+)?)([kKmMbB])?\b"#)
    private static let codeAmount = RegexPattern(#"(?i)\b([a-z]{3,4})(\d[\d,]*(?:\.\d+)?)([kmb])?\b"#)
    private static let amountCode = RegexPattern(#"(?i)\b(\d[\d,]*(?:\.\d+)?)([kmb])\s+([a-z]{3,4})\b"#)
    private static let bareThousandsOrBillions = RegexPattern(#"(?i)\b(\d[\d,]*(?:\.\d+)?)([kb])\b"#)
    private static let codeToken = RegexPattern(#"(?i)\b([a-z]{3,4})\b"#)

    /// Normalizes a raw query:
    /// - strips question scaffolding ("what is …?", "how much is …", "convert …")
    /// - rewrites wordy operators ("times", "divided by", "square root of", …)
    /// - moves currency symbols and codes behind the amount (`$100` → `100 USD`)
    /// - expands `k`/`m`/`b` shorthand (`10k` → `10000`) without touching units like `10km`
    /// - uppercases currency codes (`usd` → `USD`)
    static func normalize(_ query: String) -> String {
        var text = stripQuestion(query.collapsingWhitespace)
        text = rewriteWordyMath(text)
        text = rewriteMoneyAmounts(text)
        text = codeToken.replacingAll(in: text) { match in
            let token = match.text(1)
            return isCurrencyCode(token) ? token.uppercased() : token
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func stripQuestion(_ query: String) -> String {
        var text = query
        while true {
            let stripped = questionPrefix.replacingFirst(in: text, template: "")
            if stripped == text { break }
            text = stripped
        }
        while let last = text.last, "?= ".contains(last) {
            text.removeLast()
        }
        return text
    }

    private static func rewriteWordyMath(_ query: String) -> String {
        var text = squareRoot.replacingFirst(in: query, template: "sqrt($1)")
        text = cubeRoot.replacingFirst(in: text, template: "cbrt($1)")
        text = toThePowerOf.replacingAll(in: text, template: "^")
        text = powerWord.replacingAll(in: text, template: "$1^$2")
        text = times.replacingAll(in: text, template: " * ")
        text = dividedBy.replacingAll(in: text, template: " / ")
        text = plus.replacingAll(in: text, template: " + ")
        text = minus.replacingAll(in: text, template: " - ")
        text = squared.replacingAll(in: text, template: "($1)^2")
        text = cubed.replacingAll(in: text, template: "($1)^3")
        text = halfOf.replacingFirst(in: text, template: "($1)/2")
        return percentWord.replacingAll(in: text, template: "$1%")
    }

    private static func rewriteMoneyAmounts(_ query: String) -> String {
        // `$100` / `€50` → `100 USD` / `50 EUR`.
        var text = symbolAmount.replacingAll(in: query) { match in
            let code = symbolCodes[match.text(1)] ?? "USD"
            return "\(expandSuffix(match.text(2), suffix: match[3])) \(code)"
        }
        // `usd1k` → `1000 USD`.
        text = codeAmount.replacingAll(in: text) { match in
            guard isCurrencyCode(match.text(1)) else { return match.text(0) }
            return "\(expandSuffix(match.text(2), suffix: match[3])) \(match.text(1).uppercased())"
        }
        // `1m usd` → `1000000 usd` (`m` only expands next to a currency code).
        text = amountCode.replacingAll(in: text) { match in
            guard isCurrencyCode(match.text(3)) else { return match.text(0) }
            return "\(expandSuffix(match.text(1), suffix: match[2])) \(match.text(3))"
        }
        // Bare `10k` / `1.2b`, never `m`: that's metres.
        return bareThousandsOrBillions.replacingAll(in: text) { match in
            expandSuffix(match.text(1), suffix: match[2])
        }
    }

    /// Multiplies out a `k`/`m`/`b` suffix and renders without float noise.
    private static func expandSuffix(_ amount: String, suffix: String?) -> String {
        let clean = amount.replacingOccurrences(of: ",", with: "")
        guard let number = Double(clean) else { return clean }
        let factor: Double = switch suffix?.lowercased() {
        case "k": 1e3
        case "m": 1e6
        case "b": 1e9
        default: 1
        }
        let value = number * factor
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return CalcFormat.plain(value)
    }
}
