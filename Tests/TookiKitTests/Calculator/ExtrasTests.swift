// Ported from asyar-calculator/src/extras.rs @ 034a38c
import Testing
@testable import TookiKit

struct ExtrasTests {
    @Test func ratioSimplifiesByGcd() throws {
        let result = try #require(RatioPhrase.evaluate("ratio of 384 to 240"))
        #expect(result.value == "8 : 5")
        #expect(result.kind == .ratio)
        #expect(result.detail.contains("1.6"))
    }

    @Test func ratioAlreadyReduced() {
        #expect(RatioPhrase.evaluate("ratio of 3 to 5")?.value == "3 : 5")
    }

    @Test func ratioWithDecimals() {
        #expect(RatioPhrase.evaluate("ratio of 1.5 to 3")?.value == "1 : 2")
    }

    @Test func ratioRejectsOtherQueries() {
        #expect(RatioPhrase.evaluate("ratio") == nil)
        #expect(RatioPhrase.evaluate("2+2") == nil)
    }

    @Test func hexLiteralShowsAllBases() throws {
        let result = try #require(BaseConversion.evaluate("0xff"))
        #expect(result.value == "255")
        #expect(result.kind == .base)
        #expect(result.detail.contains("0b11111111"))
        #expect(result.detail.contains("0o377"))
    }

    @Test func binaryAndOctalLiterals() {
        #expect(BaseConversion.evaluate("0b1010")?.value == "10")
        #expect(BaseConversion.evaluate("0o755")?.value == "493")
    }

    @Test func decimalToBaseConversions() {
        #expect(BaseConversion.evaluate("255 to hex")?.value == "0xFF")
        #expect(BaseConversion.evaluate("12 to binary")?.value == "0b1100")
        #expect(BaseConversion.evaluate("12 in bin")?.value == "0b1100")
        #expect(BaseConversion.evaluate("8 to octal")?.value == "0o10")
    }

    @Test func basedLiteralToDecimal() {
        #expect(BaseConversion.evaluate("0x2f to decimal")?.value == "47")
        #expect(BaseConversion.evaluate("0b111 to dec")?.value == "7")
    }

    @Test func basesRejectOtherQueries() {
        #expect(BaseConversion.evaluate("hello") == nil)
        #expect(BaseConversion.evaluate("2+2") == nil)
        #expect(BaseConversion.evaluate("255") == nil)
    }

    @Test func timespanExtractsInnerExpression() {
        #expect(Timespan.innerExpression("145 min to timespan") == "145 min")
        #expect(Timespan.innerExpression("1.5 days + 2 hours as timespan") == "1.5 days + 2 hours")
        #expect(Timespan.innerExpression("145 min to hours") == nil)
    }

    @Test func timespanHoursAndMinutesPhrasing() {
        #expect(Timespan.innerExpression("145 minutes as hours and minutes") == "145 minutes")
        #expect(Timespan.innerExpression("500 min in hours and mins") == "500 min")
    }

    @Test func pixelsAtPpi() throws {
        let result = try #require(PixelConversion.evaluate("2 inches in px at 72 ppi"))
        #expect(result.value == "144 px")
        #expect(result.kind == .unit)
        #expect(PixelConversion.evaluate("1 in to px at 300 dpi")?.value == "300 px")
        #expect(PixelConversion.evaluate("2.54 cm in px at 100 ppi")?.value == "100 px")
    }

    @Test func pixelsReverseDirection() {
        #expect(PixelConversion.evaluate("144 px in inches at 72 ppi")?.value == "2 in")
    }

    @Test func pixelsRejectsOtherQueries() {
        #expect(PixelConversion.evaluate("2 inches in px") == nil)
        #expect(PixelConversion.evaluate("2+2") == nil)
    }

    @Test func formatSecondsTwoLargestUnits() {
        #expect(Timespan.format(seconds: 8700) == "2 h 25 min")
        #expect(Timespan.format(seconds: 90) == "1 min 30 s")
        #expect(Timespan.format(seconds: 90061) == "1 d 1 h")
        #expect(Timespan.format(seconds: 45) == "45 s")
        #expect(Timespan.format(seconds: 3600) == "1 h")
    }
}
