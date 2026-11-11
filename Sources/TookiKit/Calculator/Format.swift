import Foundation

/// Number and output formatting shared across the calculator pipeline.
enum CalcFormat {
    /// Inserts thousands separators into a plain unsigned integer string.
    static func groupThousands(_ digits: String) -> String {
        var result = ""
        let length = digits.count
        for (index, character) in digits.enumerated() {
            if index > 0 && (length - index) % 3 == 0 {
                result.append(",")
            }
            result.append(character)
        }
        return result
    }

    /// Thousands separators, up to 6 decimal places, no trailing zeros
    /// (`48.3`, not `48.300000`).
    static func number(_ value: Double) -> String {
        let (sign, integerDigits, fraction) = splitFixed(value, decimals: 6)
        let trimmedFraction = fraction.trimmingSuffix("0")
        let grouped = groupThousands(integerDigits)
        return trimmedFraction.isEmpty ? "\(sign)\(grouped)" : "\(sign)\(grouped).\(trimmedFraction)"
    }

    /// A monetary amount: thousands separators and exactly 2 decimals.
    static func money(_ value: Double) -> String {
        let (sign, integerDigits, fraction) = splitFixed(value, decimals: 2)
        return "\(sign)\(groupThousands(integerDigits)).\(fraction)"
    }

    /// A float the way Rust's `{}` prints it: `1` for 1.0, `1.42` for 1.42.
    static func plain(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e16 {
            return String(format: "%.0f", value)
        }
        return "\(value)"
    }

    /// Groups the integer digits of every standalone decimal number in an
    /// engine answer, leaving based literals (`0x11111`) and fraction digits
    /// alone, and swaps the `approx.` prefix for `≈`.
    static func beautify(_ engineOutput: String) -> String {
        var text = engineOutput
        if text.hasPrefix("approx. ") {
            text = "≈ " + text.dropFirst("approx. ".count)
        }
        text = text.replacingOccurrences(of: " / ", with: "/")

        let characters = Array(text)
        var result = ""
        var index = 0
        while index < characters.count {
            guard characters[index].isASCIIDigit else {
                result.append(characters[index])
                index += 1
                continue
            }
            let start = index
            while index < characters.count && characters[index].isASCIIDigit {
                index += 1
            }
            let run = String(characters[start..<index])
            let previous: Character? = start > 0 ? characters[start - 1] : nil
            let isGluedToSomething = previous.map { $0 == "." || $0 == "_" || $0.isASCIIAlphanumeric } ?? false
            result += !isGluedToSomething && run.count >= 4 ? groupThousands(run) : run
        }
        return result
    }

    /// `value` rounded to `decimals` places, split into sign, integer digits and fraction digits.
    private static func splitFixed(_ value: Double, decimals: Int) -> (sign: String, integer: String, fraction: String) {
        let formatted = String(format: "%.\(decimals)f", value)
        let parts = formatted.split(separator: ".", omittingEmptySubsequences: false)
        let integerPart = String(parts[0])
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        if integerPart.hasPrefix("-") {
            return ("-", String(integerPart.dropFirst()), fraction)
        }
        return ("", integerPart, fraction)
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
    var isASCIIAlphanumeric: Bool { isASCII && (isLetter || isNumber) }
}

extension String {
    func trimmingSuffix(_ character: Character) -> String {
        var result = self
        while result.last == character {
            result.removeLast()
        }
        return result
    }

    /// Words separated by single spaces, like Rust's `split_whitespace().join(" ")`.
    var collapsingWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
