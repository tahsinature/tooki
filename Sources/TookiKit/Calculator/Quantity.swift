import Foundation

/// Exponents of the base dimensions a quantity is measured in.
/// Angles and percentages are dimensionless.
struct UnitDimension: Hashable, Sendable {
    private var exponents: [Int]

    private init(_ exponents: [Int]) {
        self.exponents = exponents
    }

    private static func base(_ index: Int) -> UnitDimension {
        var exponents = Array(repeating: 0, count: 6)
        exponents[index] = 1
        return UnitDimension(exponents)
    }

    static let none = UnitDimension(Array(repeating: 0, count: 6))
    static let length = base(0)
    static let mass = base(1)
    static let time = base(2)
    static let temperature = base(3)
    static let information = base(4)
    static let currency = base(5)

    static let area = length * length
    static let volume = area * length
    static let speed = length / time
    static let energy = mass * area / time / time
    static let power = energy / time
    static let pressure = mass / length / time / time
    static let frequency = none / time
    static let dataRate = information / time

    var isDimensionless: Bool { self == .none }
    var involvesCurrency: Bool { exponents[5] != 0 }

    static func * (lhs: UnitDimension, rhs: UnitDimension) -> UnitDimension {
        UnitDimension(zip(lhs.exponents, rhs.exponents).map { $0 + $1 })
    }

    static func / (lhs: UnitDimension, rhs: UnitDimension) -> UnitDimension {
        UnitDimension(zip(lhs.exponents, rhs.exponents).map { $0 - $1 })
    }

    func raised(to power: Int) -> UnitDimension {
        UnitDimension(exponents.map { $0 * power })
    }
}

/// How a quantity is shown: its label and the size of one display unit in base units.
struct DisplayUnit: Sendable {
    let singular: String
    let plural: String
    /// Base units per display unit (metres per mile, kelvin per degree Fahrenheit, …).
    let factor: Double
    /// Temperature scales only: the scale's zero, measured in its own degrees from absolute zero.
    let offset: Double

    init(singular: String, plural: String? = nil, factor: Double, offset: Double = 0) {
        self.singular = singular
        self.plural = plural ?? singular
        self.factor = factor
        self.offset = offset
    }

    static let percent = DisplayUnit(singular: "%", factor: 0.01)

    var isPercent: Bool { singular == "%" }

    func label(forFormattedValue value: String) -> String {
        value == "1" ? singular : plural
    }
}

/// A unit looked up by name: how to show it and what it measures.
struct ResolvedUnit: Sendable {
    let display: DisplayUnit
    let dimension: UnitDimension
    /// Celsius, Fahrenheit and Kelvin, whose amounts are absolute temperatures.
    var isTemperatureScale: Bool { dimension == .temperature }

    func raised(to power: Int) -> ResolvedUnit {
        let label = "\(display.singular)^\(power)"
        return ResolvedUnit(
            display: DisplayUnit(singular: label, factor: pow(display.factor, Double(power))),
            dimension: dimension.raised(to: power)
        )
    }

    /// `sq ft`, `cubic meters`.
    func withPrefix(_ prefix: String, power: Int) -> ResolvedUnit {
        ResolvedUnit(
            display: DisplayUnit(
                singular: "\(prefix) \(display.singular)",
                plural: "\(prefix) \(display.plural)",
                factor: pow(display.factor, Double(power))
            ),
            dimension: dimension.raised(to: power)
        )
    }
}

/// A number with an optional unit, stored in base units (metres, kilograms,
/// seconds, kelvin, bits, US dollars).
struct Quantity: Sendable {
    var baseValue: Double
    var dimension: UnitDimension
    var unit: DisplayUnit?
    /// `20 °C` is a point on the scale; `20 °C - 5 °C` subtracts a temperature difference.
    var isAbsoluteTemperature = false

    static func number(_ value: Double) -> Quantity {
        Quantity(baseValue: value, dimension: .none)
    }

    init(baseValue: Double, dimension: UnitDimension, unit: DisplayUnit? = nil, isAbsoluteTemperature: Bool = false) {
        self.baseValue = baseValue
        self.dimension = dimension
        self.unit = unit
        self.isAbsoluteTemperature = isAbsoluteTemperature
    }

    init(amount: Double, unit: ResolvedUnit) {
        let display = unit.display
        if unit.isTemperatureScale {
            self.init(baseValue: (amount + display.offset) * display.factor, dimension: unit.dimension, unit: display, isAbsoluteTemperature: true)
        } else {
            self.init(baseValue: amount * display.factor, dimension: unit.dimension, unit: display)
        }
    }

    /// The number shown next to the unit label.
    var displayValue: Double {
        guard let unit else { return baseValue }
        return isAbsoluteTemperature ? baseValue / unit.factor - unit.offset : baseValue / unit.factor
    }

    var isPlainNumber: Bool { dimension.isDimensionless && (unit == nil || unit?.isPercent == true) }

    /// A temperature difference in the same unit, for arithmetic other than adding offsets.
    var asDifference: Quantity {
        guard isAbsoluteTemperature, let unit else { return self }
        return Quantity(baseValue: displayValue * unit.factor, dimension: dimension, unit: unit)
    }
}
