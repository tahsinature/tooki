// Ported from asyar-calculator/src/normalize.rs @ 034a38c
import Testing
@testable import TookiKit

struct NormalizeTests {
    @Test func stripsQuestionScaffolding() {
        #expect(Normalizer.normalize("What is 20% of 80?") == "20% of 80")
        #expect(Normalizer.normalize("how much is 5 * 3") == "5 * 3")
        #expect(Normalizer.normalize("convert 10 km to miles") == "10 km to miles")
        #expect(Normalizer.normalize("2+2=") == "2+2")
    }

    @Test func rewritesWordyMath() {
        #expect(Normalizer.normalize("square root of 625") == "sqrt(625)")
        #expect(Normalizer.normalize("cube root of 27") == "cbrt(27)")
        #expect(Normalizer.normalize("2 power 10") == "2^10")
        #expect(Normalizer.normalize("2 to the power of 10") == "2^10")
        #expect(Normalizer.normalize("7 times 8") == "7 * 8")
        #expect(Normalizer.normalize("100 divided by 4") == "100 / 4")
        #expect(Normalizer.normalize("9 plus 3") == "9 + 3")
        #expect(Normalizer.normalize("9 minus 3") == "9 - 3")
        #expect(Normalizer.normalize("5 squared") == "(5)^2")
        #expect(Normalizer.normalize("4 cubed") == "(4)^3")
        #expect(Normalizer.normalize("half of 10") == "(10)/2")
        #expect(Normalizer.normalize("20 percent of 80") == "20% of 80")
    }

    @Test func movesCurrencySymbolsBehindAmount() {
        #expect(Normalizer.normalize("$100 in eur") == "100 USD in EUR")
        #expect(Normalizer.normalize("€50 + $20 in gbp") == "50 EUR + 20 USD in GBP")
        #expect(Normalizer.normalize("£9.99") == "9.99 GBP")
    }

    @Test func uppercasesIsoCurrencyCodes() {
        #expect(Normalizer.normalize("100 usd to iqd") == "100 USD to IQD")
        #expect(Normalizer.normalize("25 usd to eur") == "25 USD to EUR")
    }

    @Test func uppercasesCryptoCodes() {
        #expect(Normalizer.normalize("5 btc in gbp") == "5 BTC in GBP")
        #expect(Normalizer.normalize("0.5 eth to usd") == "0.5 ETH to USD")
        #expect(Normalizer.normalize("100 doge in usd") == "100 DOGE in USD")
    }

    @Test func expandsAmountShorthand() {
        #expect(Normalizer.normalize("10k") == "10000")
        #expect(Normalizer.normalize("$1k in iqd") == "1000 USD in IQD")
        #expect(Normalizer.normalize("usd1k") == "1000 USD")
        #expect(Normalizer.normalize("$2.5m") == "2500000 USD")
        #expect(Normalizer.normalize("1.2b") == "1200000000")
        #expect(Normalizer.normalize("1m usd to eur") == "1000000 USD to EUR")
    }

    @Test func doesNotBreakRealUnits() {
        #expect(Normalizer.normalize("10km in miles") == "10km in miles")
        #expect(Normalizer.normalize("5m in feet") == "5m in feet")
        #expect(Normalizer.normalize("10 k") == "10 k")
    }

    @Test func leavesPlainExpressionsAlone() {
        #expect(Normalizer.normalize("2+2") == "2+2")
        #expect(Normalizer.normalize("5'10\" to cm") == "5'10\" to cm")
        #expect(Normalizer.normalize("20% off 80") == "20% off 80")
    }
}
