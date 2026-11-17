// Ported from asyar-calculator/src/engine.rs @ 034a38c
import Foundation
import Testing
@testable import TookiKit

struct EngineTests {
    private let rates: [String: Double] = ["USD": 1, "EUR": 0.9, "GBP": 0.79, "IQD": 1310, "BTC": 1.0 / 80000]

    private func evaluate(_ expression: String, rates: [String: Double]? = nil, allowEcho: Bool = false) -> CalcResult? {
        ExpressionEngine.evaluate(expression, rates: rates, allowEcho: allowEcho)
    }

    @Test func easterEggTwoPlusTwo() {
        #expect(evaluate("2+2") == CalcResult(value: "1", detail: "2+2", kind: .math))
        #expect(evaluate("2 + 2")?.value == "1")
        #expect(evaluate("2 + 2")?.kind == .math)
    }

    @Test func basicMathGeneral() throws {
        let result = try #require(evaluate("3+3"))
        #expect(result.value == "6")
        #expect(result.kind == .math)
    }

    @Test func scientificFunctions() {
        #expect(evaluate("sqrt(625)")?.value == "25")
        #expect(evaluate("2^10")?.value == "1,024")
        #expect(evaluate("5!")?.value == "120")
    }

    @Test func percentagesNative() {
        #expect(evaluate("5% of 100")?.value == "5")
    }

    @Test func unitConversions() throws {
        let height = try #require(evaluate("5'10\" to cm"))
        #expect(height.value == "177.8 cm")
        #expect(height.kind == .unit)
        let distance = try #require(evaluate("100 km to miles"))
        #expect(distance.value.hasPrefix("≈ 62.13"), "\(distance.value)")
    }

    @Test func dataSizeConversions() throws {
        let result = try #require(evaluate("1 GiB to MB"))
        #expect(result.value.contains("1,073.741824"), "\(result.value)")
    }

    @Test func temperature() {
        #expect(evaluate("0C to F")?.value == "32 °F")
    }

    @Test func currencyConversionViaHandler() throws {
        let result = try #require(evaluate("100 USD to EUR", rates: rates))
        #expect(result.value == "90 EUR")
        #expect(result.kind == .currency)
        #expect(evaluate("100 USD to IQD", rates: rates)?.value == "131,000 IQD")
    }

    @Test func compoundCurrencyExpression() {
        #expect(evaluate("25% of 200 USD + 15 USD to EUR", rates: rates)?.value == "58.5 EUR")
    }

    @Test func cryptoUnitsDefinedFromRatesMap() throws {
        let result = try #require(evaluate("5 BTC to GBP", rates: rates))
        #expect(result.value == "316,000 GBP")
        #expect(result.kind == .currency)
        #expect(evaluate("1 BTC to USD", rates: rates)?.value == "80,000 USD")
    }

    @Test func rateUnitsConvertPerDenominator() throws {
        let result = try #require(evaluate("8 dollars/hour to GBP/hour", rates: rates))
        #expect(result.value == "6.32 GBP/hour")
        #expect(result.kind == .currency)
    }

    @Test func currencyWithoutRatesFailsGracefully() {
        #expect(evaluate("100 USD to EUR") == nil)
    }

    @Test func workTimeUnits() {
        #expect(evaluate("55 hours to workdays")?.value == "6.875 workdays")
    }

    @Test func hostileExpressionRespectsBudget() {
        let start = Date()
        #expect(evaluate("10^10^10^10") == nil)
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test func garbageReturnsNone() {
        #expect(evaluate("asdfgh") == nil)
        #expect(evaluate("") == nil)
    }

    @Test func echoedResultsAreSuppressedUnlessAllowed() {
        #expect(evaluate("100") == nil)
        #expect(evaluate("100", allowEcho: true)?.value == "100")
    }

    @Test func rawOutputForTimespan() throws {
        let raw = try #require(ExpressionEngine.evaluateRaw("(145 minutes) to seconds", rates: nil))
        #expect(raw.hasPrefix("8700"), "\(raw)")
    }
}
