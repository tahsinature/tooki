// Ported from asyar-calculator/src/locale.rs @ 034a38c
import Testing
@testable import TookiKit

struct LocaleTests {
    @Test func detectsCommaLocalesFromTheRegion() {
        for tag in ["de-DE", "de_DE", "fr-FR", "pt-BR", "es-ES", "tr-TR", "nl-NL"] {
            #expect(NumberFormat.fromLocaleTag(tag) == .comma, "\(tag)")
        }
    }

    @Test func detectsPointLocalesFromTheRegion() {
        for tag in ["en-US", "en-GB", "en-AU", "ja-JP", "zh-Hans-CN", "es-MX"] {
            #expect(NumberFormat.fromLocaleTag(tag) == .point, "\(tag)")
        }
    }

    @Test func regionBeatsLanguage() {
        #expect(NumberFormat.fromLocaleTag("en-DE") == .comma)
        #expect(NumberFormat.fromLocaleTag("de-US") == .point)
        #expect(NumberFormat.fromLocaleTag("de-CH") == .point)
    }

    @Test func canadaIsDecidedByLanguage() {
        #expect(NumberFormat.fromLocaleTag("fr-CA") == .comma)
        #expect(NumberFormat.fromLocaleTag("en-CA") == .point)
    }

    @Test func fallsBackToTheLanguageWithoutARegion() {
        #expect(NumberFormat.fromLocaleTag("de") == .comma)
        #expect(NumberFormat.fromLocaleTag("en") == .point)
    }

    @Test func preferenceOverridesAreParsed() {
        #expect(NumberFormat.fromPreference("comma") == .comma)
        #expect(NumberFormat.fromPreference(" Point ") == .point)
        #expect(NumberFormat.fromPreference("auto") == nil)
        #expect(NumberFormat.fromPreference("nonsense") == nil)
    }

    @Test func canonicalizationAndLocalization() {
        let typed = "61,78*1,19"
        let canonical = NumberNotation.canonicalize(typed, from: .comma)
        #expect(canonical == "61.78*1.19")
        #expect(NumberNotation.localize(canonical, to: .comma) == typed)

        #expect(NumberNotation.canonicalize("1.234,56", from: .comma) == "1234.56")
        #expect(NumberNotation.canonicalize("1.234.567", from: .comma) == "1234567")
        #expect(NumberNotation.canonicalize("3.14 * 2", from: .comma) == "3.14 * 2")
        #expect(NumberNotation.canonicalize("1,234.56 + 3.14", from: .point) == "1,234.56 + 3.14")
    }
}
