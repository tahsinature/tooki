import Foundation

/// Built-in functions and constants of the expression engine.
enum MathFunctions {
    static let constants: [String: Double] = [
        "pi": .pi, "π": .pi, "tau": 2 * .pi, "τ": 2 * .pi, "e": M_E,
    ]

    /// Functions of a plain number.
    private static let numeric: [String: @Sendable (Double) -> Double] = [
        "sqrt": { $0.squareRoot() },
        "cbrt": { cbrt($0) },
        "ln": { log($0) },
        "log": { log10($0) },
        "log10": { log10($0) },
        "log2": { log2($0) },
        "exp": { exp($0) },
        "sin": { sin($0) },
        "cos": { cos($0) },
        "tan": { tan($0) },
        "asin": { asin($0) },
        "acos": { acos($0) },
        "atan": { atan($0) },
        "sinh": { sinh($0) },
        "cosh": { cosh($0) },
        "tanh": { tanh($0) },
    ]

    /// Functions that keep the unit: `round(2.6 km)` is `3 km`.
    private static let unitPreserving: [String: @Sendable (Double) -> Double] = [
        "abs": { abs($0) },
        "round": { $0.rounded() },
        "floor": { $0.rounded(.down) },
        "ceil": { $0.rounded(.up) },
    ]

    static func isFunction(_ name: String) -> Bool {
        numeric[name.lowercased()] != nil || unitPreserving[name.lowercased()] != nil
    }

    static func apply(_ name: String, to argument: Quantity) throws -> Quantity {
        let name = name.lowercased()
        if let function = unitPreserving[name] {
            guard let unit = argument.unit else { return .number(function(argument.baseValue)) }
            let resolved = ResolvedUnit(display: unit, dimension: argument.dimension)
            if argument.isAbsoluteTemperature {
                return Quantity(amount: function(argument.displayValue), unit: resolved)
            }
            return Quantity(baseValue: function(argument.displayValue) * unit.factor, dimension: argument.dimension, unit: unit)
        }
        guard let function = numeric[name], argument.dimension.isDimensionless else { throw ExpressionError() }
        return .number(function(argument.baseValue))
    }

    /// `n!` for whole numbers up to 170, the largest factorial a Double can hold.
    static func factorial(_ argument: Quantity) throws -> Quantity {
        let value = argument.baseValue
        guard argument.unit == nil, value >= 0, value <= 170, value == value.rounded() else { throw ExpressionError() }
        return .number((1...max(1, Int(value))).reduce(1.0) { $0 * Double($1) })
    }
}
