// Ported from asyar-calculator/src/format.rs @ 034a38c
import Testing
@testable import TookiKit

struct FormatTests {
    @Test func formatNumberBasic() {
        #expect(CalcFormat.number(4.0) == "4")
        #expect(CalcFormat.number(0.5) == "0.5")
        #expect(CalcFormat.number(1234567.0) == "1,234,567")
        #expect(CalcFormat.number(1234.5678) == "1,234.5678")
    }

    @Test func formatNumberRoundsLongDecimals() {
        #expect(CalcFormat.number(0.123456789) == "0.123457")
        #expect(CalcFormat.number(-1234.5) == "-1,234.5")
    }

    @Test func formatMoneyTwoDecimals() {
        #expect(CalcFormat.money(48.3) == "48.30")
        #expect(CalcFormat.money(1310000.0) == "1,310,000.00")
        #expect(CalcFormat.money(6.3) == "6.30")
    }

    @Test func beautifyAddsSeparatorsToPlainNumbers() {
        #expect(CalcFormat.beautify("1609.344 km") == "1,609.344 km")
        #expect(CalcFormat.beautify("131000 IQD") == "131,000 IQD")
        #expect(CalcFormat.beautify("255") == "255")
        #expect(CalcFormat.beautify("1000000") == "1,000,000")
    }

    @Test func beautifyLeavesBasedLiteralsAlone() {
        #expect(CalcFormat.beautify("0x11111") == "0x11111")
        #expect(CalcFormat.beautify("0b11111111") == "0b11111111")
        #expect(CalcFormat.beautify("0o37777") == "0o37777")
    }

    @Test func beautifyDoesNotTouchFractionDigits() {
        #expect(CalcFormat.beautify("3.14159265") == "3.14159265")
        #expect(CalcFormat.beautify("12345.67890") == "12,345.67890")
    }

    @Test func beautifyReplacesApproxPrefix() {
        #expect(CalcFormat.beautify("approx. 3.1415926536") == "≈ 3.1415926536")
    }
}
