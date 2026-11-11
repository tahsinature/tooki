// Ported from asyar-calculator/src/dates.rs @ 034a38c
import Testing
@testable import TookiKit

struct DatesTests {
    /// 2026-07-11 is a Saturday.
    private let today = CivilDate(year: 2026, month: 7, day: 11)!

    private func evaluate(_ query: String) -> CalcResult? {
        DatePhrases.evaluate(query, today: today)
    }

    @Test func daysUntilHoliday() throws {
        let result = try #require(evaluate("days until christmas"))
        #expect(result.value == "167 days")
        #expect(result.kind == .date)
        #expect(result.detail.contains("25 Dec 2026"))
    }

    @Test func daysUntilRollsToNextYearWhenPassed() throws {
        let result = try #require(evaluate("days until 31 mar"))
        #expect(result.value == "263 days")
        #expect(result.detail.contains("31 Mar 2027"))
    }

    @Test func daysUntilSynonyms() {
        #expect(evaluate("days till christmas")?.value == "167 days")
        #expect(evaluate("how many days until christmas")?.value == "167 days")
    }

    @Test func daysSincePastDate() {
        #expect(evaluate("days since 2026-01-01")?.value == "191 days")
    }

    @Test func daysBetweenTwoDates() {
        #expect(evaluate("days between 2026-01-01 and 2026-12-31")?.value == "364 days")
    }

    @Test func weeksUntil() {
        #expect(evaluate("weeks until christmas")?.value == "23.9 weeks")
    }

    @Test func datePlusDays() throws {
        #expect(try #require(evaluate("today + 45 days")).value.contains("25 Aug 2026"))
    }

    @Test func bareNumberAfterDateMeansDays() throws {
        #expect(try #require(evaluate("aug 5 + 5")).value.contains("10 Aug 2026"))
    }

    @Test func dateMinusWeeks() throws {
        #expect(try #require(evaluate("today - 2 weeks")).value.contains("27 Jun 2026"))
    }

    @Test func datePlusMonthsCalendarAware() throws {
        #expect(try #require(evaluate("2026-01-31 + 1 month")).value.contains("28 Feb 2026"))
    }

    @Test func weekdayInNWeeks() throws {
        // Week of Aug 1 2026 (Sat); its Monday is Jul 27.
        #expect(try #require(evaluate("monday in 3 weeks")).value.contains("27 Jul 2026"))
    }

    @Test func nextWeekday() throws {
        let result = try #require(evaluate("next friday"))
        #expect(result.value.contains("17 Jul 2026"))
        #expect(result.detail.contains("in 6 days"))
    }

    @Test func inNWeeks() throws {
        #expect(try #require(evaluate("in 2 weeks")).value.contains("25 Jul 2026"))
    }

    @Test func nDaysFromNow() throws {
        #expect(try #require(evaluate("45 days from now")).value.contains("25 Aug 2026"))
    }

    @Test func nUnitsAgo() throws {
        let result = try #require(evaluate("35 days ago"))
        #expect(result.value.contains("6 Jun 2026"))
        #expect(result.detail.contains("35 days ago"))
        #expect(try #require(evaluate("2 weeks ago")).value.contains("27 Jun 2026"))
    }

    @Test func daysUntilFeb29FromNonLeapYear() throws {
        // 2026 isn't a leap year; the next real Feb 29 is 2028.
        let result = try #require(evaluate("days until feb 29"))
        #expect(result.value == "598 days")
        #expect(result.detail.contains("29 Feb 2028"))
    }

    @Test func daysUntilFeb29AfterItPassedInLeapYear() throws {
        // 2029 isn't a leap year either, so the search must reach 2032.
        let marchFirst = try #require(CivilDate(year: 2028, month: 3, day: 1))
        let result = try #require(DatePhrases.evaluate("days until feb 29", today: marchFirst))
        #expect(result.value == "1460 days")
        #expect(result.detail.contains("29 Feb 2032"))
    }

    @Test func workTimeInYear() throws {
        // 2023 has 260 weekdays → 2,080 work hours at 8 h/day.
        let result = try #require(evaluate("workhours in 2023"))
        #expect(result.value == "2,080 h")
        #expect(result.detail.contains("260"))
        #expect(evaluate("workdays in 2023")?.value == "260 workdays")
        #expect(evaluate("work hours in 2023")?.value == "2,080 h")
    }

    @Test func clockTimePlusHours() {
        #expect(evaluate("3:45pm + 5")?.value == "8:45 PM")
        #expect(evaluate("3:45pm + 90 minutes")?.value == "5:15 PM")
        #expect(evaluate("11pm + 2 hours")?.value == "1:00 AM")
    }

    @Test func rejectsNonDateQueries() {
        #expect(evaluate("days") == nil)
        #expect(evaluate("until") == nil)
        #expect(evaluate("2+2") == nil)
        #expect(evaluate("100 usd to eur") == nil)
    }
}
