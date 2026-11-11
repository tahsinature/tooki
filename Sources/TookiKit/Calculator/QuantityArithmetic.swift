import Foundation

/// Thrown for anything the expression engine can't evaluate.
struct ExpressionError: Error {}

/// Unit-aware arithmetic. Results keep the left operand's unit for sums,
/// and combine labels (`km/h`, `m^2`) for products and quotients.
extension Quantity {
    func adding(_ other: Quantity) throws -> Quantity {
        try combinedSum(other, sign: 1)
    }

    func subtracting(_ other: Quantity) throws -> Quantity {
        try combinedSum(other, sign: -1)
    }

    func multiplied(by other: Quantity) throws -> Quantity {
        let left = asDifference.droppingPercent, right = other.asDifference.droppingPercent
        let dimension = left.dimension * right.dimension
        return Quantity(
            baseValue: left.baseValue * right.baseValue,
            dimension: dimension,
            unit: Self.productUnit(left.unit, right.unit, dimension: dimension)
        )
    }

    func divided(by other: Quantity) throws -> Quantity {
        let left = asDifference.droppingPercent, right = other.asDifference.droppingPercent
        guard right.baseValue != 0 else { throw ExpressionError() }
        let dimension = left.dimension / right.dimension
        return Quantity(
            baseValue: left.baseValue / right.baseValue,
            dimension: dimension,
            unit: Self.quotientUnit(left.unit, right.unit, dimension: dimension)
        )
    }

    func remainder(dividingBy other: Quantity) throws -> Quantity {
        guard dimension == other.dimension, other.baseValue != 0 else { throw ExpressionError() }
        var result = asDifference
        result.baseValue = fmod(result.baseValue, other.asDifference.baseValue)
        return result
    }

    func raised(to exponent: Quantity) throws -> Quantity {
        guard exponent.isPlainNumber else { throw ExpressionError() }
        let power = exponent.baseValue
        let base = asDifference.droppingPercent
        guard let unit = base.unit else { return .number(pow(base.baseValue, power)) }
        guard power == power.rounded(), abs(power) <= 64 else { throw ExpressionError() }
        let wholePower = Int(power)
        return Quantity(
            baseValue: pow(base.baseValue, power),
            dimension: base.dimension.raised(to: wholePower),
            unit: DisplayUnit(singular: "\(unit.singular)^\(wholePower)", factor: pow(unit.factor, power))
        )
    }

    func negated() -> Quantity {
        guard isAbsoluteTemperature, let unit else {
            var result = self
            result.baseValue = -baseValue
            return result
        }
        // `-40 °C` negates the reading on the scale, not the distance from absolute zero.
        return Quantity(amount: -displayValue, unit: ResolvedUnit(display: unit, dimension: dimension))
    }

    /// The same quantity shown in `target`, which must measure the same thing.
    func converted(to target: ResolvedUnit, isSingleUnit: Bool) throws -> Quantity {
        guard dimension == target.dimension else { throw ExpressionError() }
        let keepsAbsolute = isAbsoluteTemperature && isSingleUnit && target.isTemperatureScale
        let source = keepsAbsolute ? self : asDifference
        return Quantity(baseValue: source.baseValue, dimension: dimension, unit: target.display, isAbsoluteTemperature: keepsAbsolute)
    }

    /// `100 + 10%` is 110, like Soulver and fend.
    private func combinedSum(_ other: Quantity, sign: Double) throws -> Quantity {
        var result = self
        if other.unit?.isPercent == true, unit?.isPercent != true {
            result.baseValue = baseValue * (1 + sign * other.baseValue)
            return result
        }
        guard dimension == other.dimension else { throw ExpressionError() }
        result.unit = unit ?? other.unit
        result.baseValue = baseValue + sign * other.asDifference.baseValue
        return result
    }

    private var droppingPercent: Quantity {
        guard unit?.isPercent == true else { return self }
        return .number(baseValue)
    }

    /// A plain number keeps the other side's unit; units that cancel out leave a plain number.
    private static func productUnit(_ left: DisplayUnit?, _ right: DisplayUnit?, dimension: UnitDimension) -> DisplayUnit? {
        guard let left, let right else { return left ?? right }
        if dimension.isDimensionless { return nil }
        let label = left.singular == right.singular ? "\(left.singular)^2" : "\(left.singular) \(right.singular)"
        return DisplayUnit(singular: label, factor: left.factor * right.factor)
    }

    private static func quotientUnit(_ left: DisplayUnit?, _ right: DisplayUnit?, dimension: UnitDimension) -> DisplayUnit? {
        guard let right else { return left }
        guard let left else { return DisplayUnit(singular: "1/\(right.singular)", factor: 1 / right.factor) }
        if dimension.isDimensionless { return nil }
        return DisplayUnit(singular: "\(left.singular)/\(right.singular)", factor: left.factor / right.factor)
    }
}
