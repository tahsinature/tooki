import Foundation

/// The `hex`, `binary`, `octal` and `decimal` conversion targets.
struct BaseTarget {
    private static let radixByName = [
        "hex": 16, "hexadecimal": 16, "binary": 2, "bin": 2, "octal": 8, "oct": 8, "decimal": 10, "dec": 10,
    ]
    private static let prefixByRadix = [16: "0x", 2: "0b", 8: "0o"]

    private let radix: Int

    init?(word: String?) {
        guard let word, let radix = Self.radixByName[word.lowercased()] else { return nil }
        self.radix = radix
    }

    /// `255` → `0xFF`. Only whole plain numbers can change base.
    func convert(_ quantity: Quantity) throws -> ExpressionValue {
        let value = quantity.baseValue
        guard quantity.unit == nil, quantity.dimension.isDimensionless,
              value == value.rounded(), abs(value) < 0x1p63 else { throw ExpressionError() }
        guard let prefix = Self.prefixByRadix[radix] else { return .quantity(.number(value)) }
        let digits = String(Int64(abs(value)), radix: radix, uppercase: true)
        return .based((value < 0 ? "-" : "") + prefix + digits)
    }
}
