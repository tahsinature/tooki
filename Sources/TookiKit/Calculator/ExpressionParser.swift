import Foundation

/// What an expression evaluates to: a quantity, or an integer already
/// written in another base (`255 to hex` → `0xFF`).
enum ExpressionValue {
    case quantity(Quantity)
    case based(String)
}

/// Recursive-descent parser and evaluator for math, unit and currency
/// expressions. It replaces fend-core.
///
///     statement := sum (("to" | "as" | "in") target)*
///     sum       := product (("+" | "-") product)*
///     product   := signed (("*" | "/" | "of" | "per" | "mod") signed | implicit signed)*
///     signed    := ("-" | "+") signed | power
///     power     := postfix ("^" signed)?
///     postfix   := primary ("!" | "%")*
///     primary   := amount | "(" sum ")" | constant | function primary | unit
struct ExpressionParser {
    private static let keywords: Set<String> = ["to", "as", "in", "of", "per", "mod"]
    private static let conversionKeywords: Set<String> = ["to", "as", "in"]
    private static let unitPowerPrefixes = ["square": 2, "sq": 2, "cubic": 3, "cu": 3]

    private let tokens: [ExpressionToken]
    private let rates: [String: Double]?
    private var position = 0

    static func evaluate(_ text: String, rates: [String: Double]?) throws -> ExpressionValue {
        guard let tokens = ExpressionTokenizer.tokenize(text), !tokens.isEmpty else { throw ExpressionError() }
        var parser = ExpressionParser(tokens: tokens, rates: rates)
        return try parser.parseStatement()
    }

    private init(tokens: [ExpressionToken], rates: [String: Double]?) {
        self.tokens = tokens
        self.rates = rates
    }

    // MARK: - Grammar

    private mutating func parseStatement() throws -> ExpressionValue {
        var quantity = try parseSum()
        while isConversionKeyword(at: position) {
            position += 1
            if let radix = BaseTarget(word: peekWord()) {
                position += 1
                guard position == tokens.count else { throw ExpressionError() }
                return try radix.convert(quantity)
            }
            let target = try parseTargetUnit()
            quantity = try quantity.converted(to: target.unit, isSingleUnit: target.isSingleUnit)
        }
        guard position == tokens.count else { throw ExpressionError() }
        return .quantity(quantity)
    }

    private mutating func parseSum() throws -> Quantity {
        var result = try parseProduct()
        while true {
            if consume(symbol: "+") {
                result = try result.adding(parseProduct())
            } else if consume(symbol: "-") {
                result = try result.subtracting(parseProduct())
            } else {
                return result
            }
        }
    }

    private mutating func parseProduct() throws -> Quantity {
        var result = try parseSigned()
        while true {
            if consume(symbol: "*") || consume(word: "of") {
                result = try result.multiplied(by: parseSigned())
            } else if consume(symbol: "/") || consume(word: "per") {
                result = try result.divided(by: parseSigned())
            } else if consume(word: "mod") {
                result = try result.remainder(dividingBy: parseSigned())
            } else if startsImplicitMultiplication() {
                result = try result.multiplied(by: parseSigned())
            } else {
                return result
            }
        }
    }

    private mutating func parseSigned() throws -> Quantity {
        if consume(symbol: "-") {
            return try parseSigned().negated()
        }
        if consume(symbol: "+") {
            return try parseSigned()
        }
        return try parsePower()
    }

    private mutating func parsePower() throws -> Quantity {
        let base = try parsePostfix()
        guard consume(symbol: "^") else { return base }
        return try base.raised(to: parseSigned())
    }

    private mutating func parsePostfix() throws -> Quantity {
        var result = try parsePrimary()
        while true {
            if consume(symbol: "!") {
                result = try MathFunctions.factorial(result)
            } else if consume(symbol: "%") {
                guard result.unit == nil, result.dimension.isDimensionless else { throw ExpressionError() }
                result = Quantity(baseValue: result.baseValue / 100, dimension: .none, unit: .percent)
            } else {
                return result
            }
        }
    }

    private mutating func parsePrimary() throws -> Quantity {
        guard position < tokens.count else { throw ExpressionError() }
        switch tokens[position] {
        case .number(let value):
            position += 1
            return try parseAmount(startingWith: value)
        case .symbol("("):
            position += 1
            let inner = try parseSum()
            guard consume(symbol: ")") else { throw ExpressionError() }
            return inner
        case .word(let word):
            if let constant = MathFunctions.constants[word.lowercased()] {
                position += 1
                return .number(constant)
            }
            if MathFunctions.isFunction(word) {
                position += 1
                return try MathFunctions.apply(word, to: parsePrimary())
            }
            guard let unit = parseUnit() else { throw ExpressionError() }
            return Quantity(amount: 1, unit: unit)
        case .symbol:
            throw ExpressionError()
        }
    }

    /// `5 km`, `3 m^2`, `5'10"`, `1 h 30 min`.
    private mutating func parseAmount(startingWith value: Double) throws -> Quantity {
        guard let unit = parseAmountUnit() else { return .number(value) }
        var total = Quantity(amount: value, unit: unit)
        while let (nextValue, nextUnit) = parseFollowingAmount(sameDimensionAs: unit) {
            total = try total.adding(Quantity(amount: nextValue, unit: nextUnit))
        }
        return total
    }

    /// The unit right after a number, with an optional integer power (`m^2`).
    private mutating func parseAmountUnit() -> ResolvedUnit? {
        guard let word = peekWord()?.lowercased(), !Self.keywords.contains(word) || startsInchAmount(word) else { return nil }
        guard let unit = parseUnit() else { return nil }
        if case .symbol("^") = token(at: position), case .number(let power) = token(at: position + 1),
           power == power.rounded(), power >= 1, power <= 64 {
            position += 2
            return unit.raised(to: Int(power))
        }
        return unit
    }

    /// `in` after a number means inches unless a conversion target follows (`5 km in miles`).
    private func startsInchAmount(_ word: String) -> Bool {
        word == "in" && !isConversionKeyword(at: position)
    }

    /// The `10"` in `5'10"`: another number and unit of the same kind.
    private mutating func parseFollowingAmount(sameDimensionAs unit: ResolvedUnit) -> (Double, ResolvedUnit)? {
        guard !unit.isTemperatureScale, case .number(let value) = token(at: position) else { return nil }
        let start = position
        position += 1
        if let next = parseAmountUnit(), next.dimension == unit.dimension {
            return (value, next)
        }
        position = start
        return nil
    }

    // MARK: - Conversion targets

    private struct TargetUnit {
        let unit: ResolvedUnit
        let isSingleUnit: Bool
    }

    /// `miles`, `GBP/hour`, `km per h`, `m^2`.
    private mutating func parseTargetUnit() throws -> TargetUnit {
        guard let first = parseTargetTerm() else { throw ExpressionError() }
        var factor = first.unit.display.factor
        var dimension = first.unit.dimension
        var label = first.label
        var termCount = 1
        while true {
            let isDivision: Bool
            if consume(symbol: "/") || consume(word: "per") {
                isDivision = true
            } else if consume(symbol: "*") || peekWord().map({ !Self.keywords.contains($0.lowercased()) }) == true {
                isDivision = false
            } else {
                break
            }
            guard let term = parseTargetTerm() else { throw ExpressionError() }
            factor = isDivision ? factor / term.unit.display.factor : factor * term.unit.display.factor
            dimension = isDivision ? dimension / term.unit.dimension : dimension * term.unit.dimension
            label += (isDivision ? "/" : " ") + term.label
            termCount += 1
        }
        guard termCount > 1 else { return TargetUnit(unit: first.unit, isSingleUnit: true) }
        let compound = ResolvedUnit(display: DisplayUnit(singular: label, factor: factor), dimension: dimension)
        return TargetUnit(unit: compound, isSingleUnit: false)
    }

    /// One unit of a target and the text it was typed as.
    private mutating func parseTargetTerm() -> (unit: ResolvedUnit, label: String)? {
        let start = position
        guard let unit = parseUnit() else { return nil }
        var label = (start..<position).compactMap { index -> String? in
            if case .word(let word) = tokens[index] { return word }
            return nil
        }.joined(separator: " ")
        if consume(symbol: "^") {
            guard case .number(let power) = token(at: position), power == power.rounded(), power <= 64 else { return nil }
            position += 1
            label += "^\(Int(power))"
            return (unit.raised(to: Int(power)), label)
        }
        return (unit, label)
    }

    // MARK: - Unit lookup

    /// Consumes and resolves the unit at the current position:
    /// a two-word name, a `square`/`cubic` prefix, a currency code from the rates
    /// (`CUP` is the Cuban peso, not a cup), an exact unit, then a
    /// case-insensitive abbreviation (`f` for `°F`).
    private mutating func parseUnit() -> ResolvedUnit? {
        guard let first = peekWord() else { return nil }
        if let second = word(at: position + 1), let unit = UnitTable.exact("\(first) \(second)") {
            position += 2
            return unit
        }
        if let power = Self.unitPowerPrefixes[first.lowercased()], let second = word(at: position + 1),
           let unit = resolveSingleWord(second) {
            position += 2
            return unit.withPrefix(first, power: power)
        }
        guard let unit = resolveSingleWord(first) else { return nil }
        position += 1
        return unit
    }

    private func resolveSingleWord(_ word: String) -> ResolvedUnit? {
        CurrencyUnits.resolve(word, rates: rates) ?? UnitTable.exact(word) ?? UnitTable.caseInsensitive(word)
    }

    // MARK: - Token helpers

    private func token(at index: Int) -> ExpressionToken? {
        index < tokens.count ? tokens[index] : nil
    }

    private func word(at index: Int) -> String? {
        if case .word(let word) = token(at: index) { return word }
        return nil
    }

    private func peekWord() -> String? {
        word(at: position)
    }

    /// `to` and `as` always convert; `in` only when a unit name follows it.
    private func isConversionKeyword(at index: Int) -> Bool {
        guard let keyword = word(at: index)?.lowercased(), Self.conversionKeywords.contains(keyword) else { return false }
        if keyword != "in" { return true }
        guard let next = word(at: index + 1) else { return false }
        return !Self.keywords.contains(next.lowercased())
    }

    /// `2 pi`, `3(4 + 1)`, `5 km h`: a parenthesis or a non-keyword word follows directly.
    private func startsImplicitMultiplication() -> Bool {
        if case .symbol("(") = token(at: position) { return true }
        guard let word = peekWord() else { return false }
        return !Self.keywords.contains(word.lowercased())
    }

    private mutating func consume(symbol: Character) -> Bool {
        guard case .symbol(symbol) = token(at: position) else { return false }
        position += 1
        return true
    }

    private mutating func consume(word expected: String) -> Bool {
        guard peekWord()?.lowercased() == expected else { return false }
        position += 1
        return true
    }
}
