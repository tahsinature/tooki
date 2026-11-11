// Ported from asyar-calculator/src/lib.rs @ 034a38c
import Foundation
import Testing
@testable import TookiKit

struct CalculatorTests {
    private static let rates: [String: Double] = [
        "USD": 1, "EUR": 0.9, "GBP": 0.79, "IQD": 1310, "BTC": 1.0 / 80000,
    ]

    /// 2026-07-11 12:00 UTC (15:00 in Baghdad), preferred currency IQD.
    private static func context(_ numberFormat: NumberFormat = .point) -> CalculatorContext {
        CalculatorContext(
            now: Date(timeIntervalSince1970: 1_783_771_200),
            timeZone: TimeZone(identifier: "Asia/Baghdad")!,
            numberFormat: numberFormat,
            rates: rates,
            ratesAge: "2 h",
            preferredCurrency: "IQD"
        )
    }

    private func evaluate(_ query: String, _ numberFormat: NumberFormat = .point) -> CalcResult? {
        Calculator.evaluate(query, context: Self.context(numberFormat))
    }

    @Test func gateRejectsAppSearchQueries() {
        #expect(!InputGate.shouldAttempt("safari"))
        #expect(!InputGate.shouldAttempt("settings"))
        #expect(!InputGate.shouldAttempt("e"))
        #expect(!InputGate.shouldAttempt(""))
    }

    @Test func gateAcceptsCalculatorQueries() {
        for query in ["2+2", "time in tokyo", "days until christmas", "#ff8800", "sqrt(2)", "pi * 2", "pi", "pi/4"] {
            #expect(InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func gateRejectsUrlsAndPaths() {
        for query in [
            "https://github.com/Xoshbin/asyar/issues/895", "http://localhost:5173", "www.example2.com",
            "web3.com", "github.com/user/repo2", "~/Projects/app2", "/Users/a/project2",
        ] {
            #expect(!InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func gateRejectsLocalhostAndIpAddresses() {
        for query in [
            "localhost:5173", "localhost:5173/settings", "LOCALHOST:3000",
            "127.0.0.1", "127.0.0.1:8080", "192.168.1.10/admin",
        ] {
            #expect(!InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func gateStillAcceptsRatiosTimesAndDecimals() {
        for query in ["10:30", "5:30 pm", "1.2.3 + 1", "localhost + 1"] {
            #expect(InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func gateStillAcceptsMathWithSlashesAndDots() {
        for query in ["1/2", "10/5/2", "3.14*2", "1.5km in m", "2.5 kg in lb"] {
            #expect(InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func pastedIssueUrlProducesNoResult() {
        #expect(evaluate("https://github.com/Xoshbin/asyar/issues/895") == nil)
    }

    @Test func gatePiPrefixDoesNotSwallowOrdinaryWords() {
        for query in ["pictures", "pinterest", "pixel", "pin", "pipe"] {
            #expect(!InputGate.shouldAttempt(query), "\(query)")
        }
    }

    @Test func commaLocaleReadsCommasAsDecimals() throws {
        let result = try #require(evaluate("61,78*1,19", .comma))
        #expect(result.value == "73,5182")
        #expect(result.detail == "61,78*1,19")
        #expect(result.kind == .math)
    }

    @Test func commaLocaleGroupsTheAnswerWithPoints() {
        #expect(evaluate("1234 * 1000", .comma)?.value == "1.234.000")
    }

    @Test func commaLocaleReadsPointGroupedInput() {
        #expect(evaluate("1.234,5 + 0,5", .comma)?.value == "1.235")
    }

    @Test func commaLocaleHandlesPercentPhrases() throws {
        let result = try #require(evaluate("19% of 61,78", .comma))
        #expect(result.kind == .percent)
        #expect(result.value == "11,7382")
    }

    @Test func commaLocaleLeavesColorListsAlone() throws {
        let result = try #require(evaluate("rgb(255,0,0) to hex", .comma))
        #expect(result.kind == .color)
        #expect(result.value == "#FF0000")
    }

    @Test func commaLocaleLeavesDatesAlone() throws {
        let point = try #require(evaluate("days until dec 25, 2026"))
        #expect(evaluate("days until dec 25, 2026", .comma)?.value == point.value)
    }

    /// Every handler must answer a comma-decimal query with exactly the
    /// point-decimal answer, re-spelled.
    @Test func commaLocaleAnswersMatchThePointLocaleAnswers() throws {
        let pairs = [
            ("61.78*1.19", "61,78*1,19"),
            ("1234567 + 1", "1.234.567 + 1"),
            ("1.5 km in miles", "1,5 km in miles"),
            ("100.50 usd in eur", "100,50 usd in eur"),
            ("20% of 61.78", "20% of 61,78"),
            ("12.5% off 80", "12,5% off 80"),
            ("increase 61.78 by 19%", "increase 61,78 by 19%"),
            ("% change from 61.78 to 73.52", "% change from 61,78 to 73,52"),
            ("1.5 cups to ml", "1,5 cups to ml"),
            ("1.5 hours to timespan", "1,5 hours to timespan"),
            ("sqrt(2)", "sqrt(2)"),
            ("0xFF", "0xFF"),
            ("#ff8800", "#ff8800"),
            ("rgb(255,0,0) to hex", "rgb(255,0,0) to hex"),
            ("ratio of 16 to 9", "ratio of 16 to 9"),
            ("days until dec 25", "days until dec 25"),
            ("today + 45 days", "today + 45 days"),
            ("5pm ldn in sf", "5pm ldn in sf"),
            ("5'10\" to cm", "5'10\" to cm"),
            ("10km in miles", "10km in miles"),
            ("50 usd", "50 usd"),
        ]
        for (pointQuery, commaQuery) in pairs {
            let point = try #require(evaluate(pointQuery), "no answer for \(pointQuery)")
            let comma = try #require(evaluate(commaQuery, .comma), "no answer for \(commaQuery)")
            #expect(comma.value == NumberNotation.localize(point.value, to: .comma), "\(commaQuery) vs \(pointQuery)")
        }
    }

    @Test func pointLocaleIsUnchanged() {
        #expect(evaluate("1234 * 1000")?.value == "1,234,000")
    }

    @Test func pipelineBasicMath() throws {
        let easterEgg = try #require(evaluate("2+2"))
        #expect(easterEgg.value == "1")
        #expect(easterEgg.kind == .math)
        let sum = try #require(evaluate("3+3"))
        #expect(sum.value == "6")
        #expect(sum.kind == .math)
    }

    @Test func pipelinePercentOffTakesPriorityOverFend() throws {
        let result = try #require(evaluate("20% off 80"))
        #expect(result.kind == .percent)
        #expect(result.value == "64")
    }

    @Test func pipelineHexLiteralShowsBaseCard() throws {
        let result = try #require(evaluate("0xff"))
        #expect(result.kind == .base)
        #expect(result.value == "255")
    }

    @Test func pipelineColor() {
        #expect(evaluate("#f80")?.kind == .color)
    }

    @Test func pipelineCurrencyWithShorthand() throws {
        let result = try #require(evaluate("$1k in iqd"))
        #expect(result.kind == .currency)
        #expect(result.value.contains("IQD"))
        #expect(result.value.contains("1,310,000"))
    }

    @Test func pipelineEmptyQueryReturnsNothing() {
        #expect(evaluate("") == nil)
        #expect(evaluate("safari") == nil)
    }

    @Test func pipelineTimespan() {
        #expect(evaluate("145 min to timespan")?.value == "2 h 25 min")
    }

    @Test func pipelineNaturalLanguageMath() {
        #expect(evaluate("square root of 625")?.value == "25")
    }

    @Test func pipelineImplicitConversionToPreferredCurrency() throws {
        let bareAmount = try #require(evaluate("50 usd"))
        #expect(bareAmount.kind == .currency)
        #expect(bareAmount.value.contains("65,500 IQD"))
        #expect(try #require(evaluate("$100")).value.contains("131,000 IQD"))
        #expect(evaluate("50 iqd") == nil)
    }

    @Test func pipelineCryptoConversion() throws {
        let result = try #require(evaluate("5 btc in gbp"))
        #expect(result.value == "316,000 GBP")
        #expect(result.kind == .currency)
    }

    @Test func pipelineRateUnitConversion() {
        #expect(evaluate("8 dollars/hour in gbp")?.value == "6.32 GBP/hour")
    }

    @Test func pipelineCookingAndPixels() {
        #expect(evaluate("1 tablespoon of honey in grams")?.value == "21 g")
        #expect(evaluate("2 inches in px at 72 ppi")?.value == "144 px")
    }

    @Test func pipelineWallTimeWithCountryAndCapitalization() {
        #expect(evaluate("8pm chile in London")?.value == "01:00")
    }

    @Test func pipelineTimespanHoursAndMinutes() {
        #expect(evaluate("145 minutes as hours and minutes")?.value == "2 h 25 min")
    }

    @Test func pipelineDaysAgoAndWorkhours() {
        #expect(evaluate("35 days ago")?.kind == .date)
        #expect(evaluate("workhours in 2023")?.value == "2,080 h")
    }

    @Test func pipelineToleratesTrailingOperatorWhileTyping() {
        #expect(evaluate("2+2+")?.value == "1")
        #expect(evaluate("3+3+")?.value == "6")
        #expect(evaluate("100 * (")?.value == "100")
    }

    /// Adapted: Asyar checks its Tauri state object; Tooki's equivalent is `CurrencyRates`.
    @Test func stateSnapshotEmptyByDefault() {
        let missingFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("no-such-rates.json")
        let snapshot = CurrencyRates(cacheURL: missingFile).snapshot()
        #expect(snapshot.rates == nil)
        #expect(snapshot.age == nil)
    }
}
