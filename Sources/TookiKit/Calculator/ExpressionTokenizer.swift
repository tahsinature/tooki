import Foundation

enum ExpressionToken: Equatable, Sendable {
    case number(Double)
    case word(String)
    /// One of `+ - * / ^ ( ) ! % ,`.
    case symbol(Character)
}

/// Splits an expression into numbers, words and operator symbols.
/// Returns `nil` for characters the engine doesn't understand.
enum ExpressionTokenizer {
    private static let symbols: Set<Character> = ["+", "-", "*", "/", "^", "(", ")", "!", "%", ","]
    private static let symbolAliases: [Character: Character] = ["×": "*", "÷": "/", "−": "-"]

    static func tokenize(_ text: String) -> [ExpressionToken]? {
        let characters = Array(text)
        var tokens: [ExpressionToken] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            if character.isWhitespace {
                index += 1
            } else if character.isASCIIDigit || (character == "." && next?.isASCIIDigit == true) {
                guard let (value, end) = readNumber(characters, from: index) else { return nil }
                tokens.append(.number(value))
                index = end
            } else if character == "*" && next == "*" {
                tokens.append(.symbol("^"))
                index += 2
            } else if character == "-" && next == ">" {
                tokens.append(.word("to"))
                index += 2
            } else if let symbol = symbolAliases[character] ?? (symbols.contains(character) ? character : nil) {
                tokens.append(.symbol(symbol))
                index += 1
            } else if character == "'" || character == "\"" {
                tokens.append(.word(String(character)))
                index += 1
            } else if character.isLetter || character == "°" {
                var end = index + 1
                while end < characters.count, characters[end].isLetter || characters[end].isNumber || characters[end] == "_" {
                    end += 1
                }
                tokens.append(.word(String(characters[index..<end])))
                index = end
            } else {
                return nil
            }
        }
        return tokens
    }

    /// Reads `1,234.5e-3`, `.5`, `0xff`, `0b101` or `0o17`. Rejects `1.2.3`.
    private static func readNumber(_ characters: [Character], from start: Int) -> (Double, Int)? {
        if let based = readBasedLiteral(characters, from: start) {
            return based
        }
        var digits = ""
        var index = start
        func isDigit(at position: Int) -> Bool {
            position < characters.count && characters[position].isASCIIDigit
        }
        func appendDigits() {
            while isDigit(at: index) {
                digits.append(characters[index])
                index += 1
            }
        }

        appendDigits()
        // Thousands groups: exactly three digits after each comma.
        while index < characters.count, characters[index] == ",",
              isDigit(at: index + 1), isDigit(at: index + 2), isDigit(at: index + 3), !isDigit(at: index + 4) {
            index += 1
            appendDigits()
        }
        if index < characters.count, characters[index] == ".", isDigit(at: index + 1) {
            digits.append(".")
            index += 1
            appendDigits()
        }
        if index < characters.count, characters[index] == "e" || characters[index] == "E" {
            let hasSign = index + 1 < characters.count && (characters[index + 1] == "+" || characters[index + 1] == "-")
            let firstExponentDigit = index + (hasSign ? 2 : 1)
            if isDigit(at: firstExponentDigit) {
                digits += String(characters[index..<firstExponentDigit])
                index = firstExponentDigit
                appendDigits()
            }
        }
        if index < characters.count, characters[index] == ".", isDigit(at: index + 1) {
            return nil
        }
        guard let value = Double(digits) else { return nil }
        return (value, index)
    }

    private static func readBasedLiteral(_ characters: [Character], from start: Int) -> (Double, Int)? {
        guard characters[start] == "0", start + 1 < characters.count else { return nil }
        let radix: Int
        switch characters[start + 1] {
        case "x", "X": radix = 16
        case "b", "B": radix = 2
        case "o", "O": radix = 8
        default: return nil
        }
        var end = start + 2
        while end < characters.count, characters[end].isASCIIAlphanumeric {
            end += 1
        }
        guard let value = UInt64(String(characters[(start + 2)..<end]), radix: radix) else { return nil }
        return (Double(value), end)
    }
}
