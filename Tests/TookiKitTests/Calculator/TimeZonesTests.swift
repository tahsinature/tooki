// Ported from asyar-calculator/src/timezone.rs @ 034a38c
import Foundation
import Testing
@testable import TookiKit

struct TimeZonesTests {
    /// 2026-07-11 12:00 UTC. Local zone for tests: Asia/Baghdad (UTC+3).
    private let now = Date(timeIntervalSince1970: 1_783_771_200)
    private let baghdad = WorldZone(identifier: "Asia/Baghdad")!

    private func evaluate(_ query: String) -> CalcResult? {
        WorldClockPhrases.evaluate(query, now: now, localZone: baghdad)
    }

    private func zoneIdentifier(_ name: String) -> String? {
        ZoneNames.resolve(name)?.identifier
    }

    @Test func resolvesAliasesAndIanaSegments() {
        #expect(zoneIdentifier("tokyo") == "Asia/Tokyo")
        #expect(zoneIdentifier("sf") == "America/Los_Angeles")
        #expect(zoneIdentifier("ldn") == "Europe/London")
        #expect(zoneIdentifier("nyc") == "America/New_York")
        #expect(zoneIdentifier("kathmandu") == "Asia/Kathmandu")
        #expect(zoneIdentifier("new york") == "America/New_York")
        #expect(zoneIdentifier("pst") == "America/Los_Angeles")
        #expect(zoneIdentifier("est") == "America/New_York")
        #expect(zoneIdentifier("nowhereville") == nil)
        #expect(zoneIdentifier("buenos aires") == "America/Argentina/Buenos_Aires")
    }

    @Test func resolvesCountryNames() {
        #expect(zoneIdentifier("chile") == "America/Santiago")
        #expect(zoneIdentifier("japan") == "Asia/Tokyo")
        #expect(zoneIdentifier("germany") == "Europe/Berlin")
        #expect(zoneIdentifier("india") == "Asia/Kolkata")
    }

    @Test func wallTimeConversionWithCountryNames() {
        // 8pm Santiago (-4 in July) = 00:00 UTC = 01:00 London (BST).
        #expect(evaluate("8pm chile in london")?.value == "01:00")
    }

    @Test func timeInCity() throws {
        let result = try #require(evaluate("time in tokyo"))
        #expect(result.value == "21:00")
        #expect(result.kind == .time)
        #expect(result.detail.contains("Tokyo"))
    }

    @Test func cityTimeSuffixForm() {
        #expect(evaluate("tokyo time")?.value == "21:00")
    }

    @Test func timeInCityWithOddOffset() {
        #expect(evaluate("time in kathmandu")?.value == "17:45")
    }

    @Test func wallTimeConversionBetweenCities() throws {
        // 5pm London (BST, +1) = 16:00 UTC = 09:00 Los Angeles (PDT, -7).
        let result = try #require(evaluate("5pm ldn in sf"))
        #expect(result.value == "09:00")
        #expect(result.detail.contains("London"))
    }

    @Test func abbreviationConversion() {
        #expect(evaluate("3pm est in pst")?.value == "12:00")
    }

    @Test func wallTimeToLocal() {
        #expect(evaluate("5pm tokyo")?.value == "11:00")
    }

    @Test func timeDiff() throws {
        // Paris in July is CEST (+2); Baghdad is +3, so Paris is 1 h behind.
        let result = try #require(evaluate("time diff paris"))
        #expect(result.value.contains("1 h"))
        #expect(result.value.contains("behind"))
    }

    @Test func timeInNHoursLocal() {
        #expect(evaluate("time in 4 hours")?.value == "19:00")
    }

    @Test func timeInNHoursInCity() {
        #expect(evaluate("time in 4 hours in tokyo")?.value == "01:00")
    }

    @Test func rejectsNonTimeQueries() {
        #expect(evaluate("time") == nil)
        #expect(evaluate("timer 10") == nil)
        #expect(evaluate("2+2") == nil)
        #expect(evaluate("time in nowhereville") == nil)
    }
}
