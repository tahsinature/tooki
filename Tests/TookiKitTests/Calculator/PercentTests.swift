// Ported from asyar-calculator/src/percent.rs @ 034a38c
import Testing
@testable import TookiKit

struct PercentTests {
    @Test func percentOf() throws {
        let result = try #require(PercentPhrases.evaluate("52% of 900"))
        #expect(result.value == "468")
        #expect(result.kind == .percent)
    }

    @Test func percentOffDiscount() throws {
        let result = try #require(PercentPhrases.evaluate("20% off 80"))
        #expect(result.value == "64")
        #expect(result.detail.contains("16"))
    }

    @Test func tipOn() throws {
        let result = try #require(PercentPhrases.evaluate("15% tip on 42"))
        #expect(result.value == "48.30")
        #expect(result.detail.contains("6.30"))
    }

    @Test func addSubtractPercent() {
        #expect(PercentPhrases.evaluate("80 + 20%")?.value == "96")
        #expect(PercentPhrases.evaluate("80 - 20%")?.value == "64")
    }

    @Test func addPercentWithAmountShorthand() {
        #expect(PercentPhrases.evaluate("19m + 47%")?.value == "27,930,000")
        #expect(PercentPhrases.evaluate("1.2k + 10%")?.value == "1,320")
    }

    @Test func whatPercentOf() {
        #expect(PercentPhrases.evaluate("12 is what % of 80")?.value == "15%")
        #expect(PercentPhrases.evaluate("12 is what percent of 80")?.value == "15%")
    }

    @Test func percentChange() {
        #expect(PercentPhrases.evaluate("% change from 80 to 96")?.value == "+20%")
        #expect(PercentPhrases.evaluate("% change from 96 to 80")?.value == "-16.67%")
    }

    @Test func increaseDecreaseByPercent() {
        #expect(PercentPhrases.evaluate("increase 80 by 20%")?.value == "96")
        #expect(PercentPhrases.evaluate("decrease 80 by 20%")?.value == "64")
    }

    @Test func handlesThousandsSeparatorsInInput() {
        #expect(PercentPhrases.evaluate("10% off 1,200")?.value == "1,080")
    }

    @Test func rejectsNonPercentQueries() {
        #expect(PercentPhrases.evaluate("20% offset") == nil)
        #expect(PercentPhrases.evaluate("off 80") == nil)
        #expect(PercentPhrases.evaluate("2+2") == nil)
        #expect(PercentPhrases.evaluate("100 usd to eur") == nil)
    }
}
