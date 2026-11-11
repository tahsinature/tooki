import Foundation

/// Category of a calculator answer. Drives icon selection in the UI.
public enum CalcKind: String, Sendable, Codable, CaseIterable {
    case math
    case unit
    case currency
    case date
    case time
    case base
    case color
    case percent
    case ratio
}

/// One calculator answer, ready for display.
public struct CalcResult: Sendable, Codable, Hashable {
    /// Main display value, e.g. `"177.8 cm"`.
    public var value: String
    /// Supporting line, e.g. the resolved date, the rate age or the query itself.
    public var detail: String
    public var kind: CalcKind

    public init(value: String, detail: String, kind: CalcKind) {
        self.value = value
        self.detail = detail
        self.kind = kind
    }

    /// What the copy action puts on the clipboard: the value without its `≈ ` marker.
    public var copyValue: String {
        value.hasPrefix("≈ ") ? String(value.dropFirst(2)) : value
    }
}

/// Everything time-, locale- and rate-dependent the pipeline needs,
/// injected so results are deterministic in tests.
public struct CalculatorContext: Sendable {
    public var now: Date
    public var timeZone: TimeZone
    /// How the user writes numbers: `1,234.56` or `1.234,56`.
    public var numberFormat: NumberFormat
    /// Units of each currency per one USD. `nil` disables currency conversion.
    public var rates: [String: Double]?
    /// Human-readable age of `rates`, e.g. `"2 h"`, shown next to currency answers.
    public var ratesAge: String?
    /// Target for bare amounts such as `50 usd`.
    public var preferredCurrency: String

    public init(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        numberFormat: NumberFormat,
        rates: [String: Double]? = nil,
        ratesAge: String? = nil,
        preferredCurrency: String = "USD"
    ) {
        self.now = now
        self.timeZone = timeZone
        self.numberFormat = numberFormat
        self.rates = rates
        self.ratesAge = ratesAge
        self.preferredCurrency = preferredCurrency
    }

    /// A context whose number notation follows `locale`.
    public init(
        now: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = .current,
        rates: [String: Double]? = nil,
        ratesAge: String? = nil,
        preferredCurrency: String = "USD"
    ) {
        self.init(
            now: now,
            timeZone: timeZone,
            numberFormat: NumberFormat.detect(locale: locale),
            rates: rates,
            ratesAge: ratesAge,
            preferredCurrency: preferredCurrency
        )
    }

    /// Today's date in `timeZone`.
    var today: CivilDate {
        CivilDate(now: now, timeZone: timeZone)
    }
}
