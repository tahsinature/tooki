// Ported from asyar-calculator/src/cooking.rs @ 034a38c
import Testing
@testable import TookiKit

struct CookingTests {
    @Test func tablespoonOfHoneyInGrams() throws {
        let result = try #require(CookingConversion.evaluate("1 tablespoon of honey in grams"))
        #expect(result.value == "21 g")
        #expect(result.kind == .unit)
        #expect(result.detail.contains("honey"))
    }

    @Test func cupsOfFlourToGrams() {
        #expect(CookingConversion.evaluate("2.5 cups of flour to grams")?.value == "312.5 g")
        #expect(CookingConversion.evaluate("1 cup of sugar in grams")?.value == "200 g")
    }

    @Test func weightBackToVolume() {
        #expect(CookingConversion.evaluate("250 g of flour in cups")?.value == "2 cups")
        #expect(CookingConversion.evaluate("125 g of flour in cups")?.value == "1 cup")
    }

    @Test func kilogramsAndOunces() {
        #expect(CookingConversion.evaluate("2 cups of water in kg")?.value == "0.47 kg")
    }

    @Test func rejectsUnknownIngredientsAndOtherQueries() {
        #expect(CookingConversion.evaluate("1 cup of unicorn to grams") == nil)
        #expect(CookingConversion.evaluate("2+2") == nil)
        #expect(CookingConversion.evaluate("100 usd to eur") == nil)
    }
}
