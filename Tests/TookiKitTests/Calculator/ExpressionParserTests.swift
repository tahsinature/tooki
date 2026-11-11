// Tooki-specific tests for the native replacement of fend-core (no upstream equivalent).
import Testing
@testable import TookiKit

struct ExpressionParserTests {
    private func value(_ expression: String) -> String? {
        ExpressionEngine.evaluate(expression, rates: nil, allowEcho: true)?.value
    }

    @Test func operatorPrecedenceAndAssociativity() {
        #expect(value("2 + 3 * 4") == "14")
        #expect(value("2 ** 3 ^ 2") == "512")
        #expect(value("-2^2") == "-4")
        #expect(value("(1 + 2) * 3") == "9")
        #expect(value("0.1 + 0.2") == "0.3")
        #expect(value("10 mod 3") == "1")
    }

    @Test func implicitMultiplicationAndConstants() {
        #expect(value("2(3 + 1)") == "8")
        #expect(value("2 pi")?.hasPrefix("≈ 6.28318") == true)
        #expect(value("sin(90 deg)") == "1")
    }

    @Test func numberLiterals() {
        #expect(value("1,000 + 1") == "1,001")
        #expect(value("1.5e3") == "1,500")
        #expect(value("0xff + 1 to hex") == "0x100")
        #expect(value("10 to binary") == "0b1010")
        #expect(value("1.2.3") == nil)
    }

    @Test func unitConversions() {
        #expect(value("10 kg in lb")?.hasPrefix("≈ 22.0462") == true)
        #expect(value("100 f to c")?.hasPrefix("≈ 37.77") == true)
        #expect(value("3 hours in minutes") == "180 minutes")
        #expect(value("1 GB to MB") == "1,000 MB")
        #expect(value("100 km/h to mph")?.hasPrefix("≈ 62.13") == true)
        #expect(value("1 sq m to sq ft")?.hasPrefix("≈ 10.76") == true)
        #expect(value("1 cups to ml") == "236.5882365 ml")
    }

    @Test func rejectsMismatchedDimensions() {
        #expect(value("5 kg to km") == nil)
        #expect(value("5 kg + 2 m") == nil)
        #expect(value("1 / 0") == nil)
    }
}
