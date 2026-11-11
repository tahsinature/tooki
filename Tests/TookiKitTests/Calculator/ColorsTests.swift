// Ported from asyar-calculator/src/colors.rs @ 034a38c
import Testing
@testable import TookiKit

struct ColorsTests {
    @Test func hexDefaultsToRgb() throws {
        let result = try #require(ColorConversion.evaluate("#ff8800"))
        #expect(result.value == "rgb(255, 136, 0)")
        #expect(result.kind == .color)
        #expect(result.detail.contains("hsl(32, 100%, 50%)"))
    }

    @Test func shortHexExpands() {
        #expect(ColorConversion.evaluate("#f80")?.value == "rgb(255, 136, 0)")
    }

    @Test func hexToHsl() {
        #expect(ColorConversion.evaluate("#ff8800 to hsl")?.value == "hsl(32, 100%, 50%)")
    }

    @Test func rgbDefaultsToHex() {
        #expect(ColorConversion.evaluate("rgb(255, 136, 0)")?.value == "#FF8800")
    }

    @Test func rgbToHslConversion() {
        #expect(ColorConversion.evaluate("rgb(255,136,0) to hsl")?.value == "hsl(32, 100%, 50%)")
    }

    @Test func hslToHex() {
        #expect(ColorConversion.evaluate("hsl(32, 100%, 50%)")?.value == "#FF8800")
    }

    @Test func pureColorsRoundtrip() {
        #expect(ColorConversion.evaluate("#000000")?.value == "rgb(0, 0, 0)")
        #expect(ColorConversion.evaluate("#ffffff")?.value == "rgb(255, 255, 255)")
        #expect(ColorConversion.evaluate("hsl(0, 100%, 50%)")?.value == "#FF0000")
    }

    @Test func rejectsInvalidColors() {
        #expect(ColorConversion.evaluate("#xyz") == nil)
        #expect(ColorConversion.evaluate("#ff88") == nil)
        #expect(ColorConversion.evaluate("rgb(300, 0, 0)") == nil)
        #expect(ColorConversion.evaluate("2+2") == nil)
    }
}
