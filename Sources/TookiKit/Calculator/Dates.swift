import Foundation

/// Natural-language date and time-of-day arithmetic: `days until christmas`,
/// `monday in 3 weeks`, `aug 5 + 5`, `3:45pm + 90 minutes`, `next friday`, `in 2 weeks`.
enum DatePhrases {
    /// How to pick a year for a yearless date like `31 mar`.
    enum Roll {
        /// Next occurrence (for "until" and arithmetic).
        case future
        /// Most recent occurrence (for "since").
        case past
    }

    private static let weekdayAlternatives = "monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thur|thurs|friday|fri|saturday|sat|sunday|sun"
    private static let daysUntil = RegexPattern(#"(?i)^(?:how\s+many\s+)?days\s+(?:until|till|til)\s+(.+)$"#)
    private static let daysSince = RegexPattern(#"(?i)^(?:how\s+many\s+)?days\s+since\s+(.+)$"#)
    private static let daysBetween = RegexPattern(#"(?i)^(?:how\s+many\s+)?days\s+between\s+(.+?)\s+and\s+(.+)$"#)
    private static let weeksUntil = RegexPattern(#"(?i)^(?:how\s+many\s+)?weeks\s+(?:until|till|til)\s+(.+)$"#)
    private static let weekdayInWeeks = RegexPattern(#"(?i)^(\#(weekdayAlternatives))\s+in\s+(\d+)\s+weeks?$"#)
    private static let inCount = RegexPattern(#"(?i)^in\s+(\d+)\s+(days?|weeks?|months?|years?)$"#)
    private static let countFromNow = RegexPattern(#"(?i)^(\d+)\s+(days?|weeks?|months?|years?)\s+from\s+(?:now|today)$"#)
    private static let countAgo = RegexPattern(#"(?i)^(\d+)\s+(days?|weeks?|months?|years?)\s+ago$"#)
    private static let workInYear = RegexPattern(#"(?i)^work\s*(?:ing\s*)?(hours|days)\s+in\s+(\d{4})$"#)
    private static let nextWeekday = RegexPattern(#"(?i)^(?:next\s+|this\s+)?(\#(weekdayAlternatives))$"#)
    private static let clock = RegexPattern(#"(?i)^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*([+-])\s*(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m)?$"#)
    private static let dateArithmetic = RegexPattern(#"(?i)^(.+?)\s*([+-])\s*(\d+)\s*(days?|weeks?|months?|years?)?$"#)

    /// Evaluates a date or time-of-day query against an injected `today`.
    static func evaluate(_ query: String, today: CivilDate) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = daysUntil.firstMatch(in: text) {
            guard let target = DateTokens.parse(match.text(1), today: today, roll: .future) else { return nil }
            return CalcResult(value: "\(target - today) days", detail: target.formatted, kind: .date)
        }

        if let match = daysSince.firstMatch(in: text) {
            guard let target = DateTokens.parse(match.text(1), today: today, roll: .past) else { return nil }
            return CalcResult(value: "\(today - target) days", detail: "since \(target.formatted)", kind: .date)
        }

        if let match = daysBetween.firstMatch(in: text) {
            guard let start = DateTokens.parse(match.text(1), today: today, roll: .future),
                  let end = DateTokens.parse(match.text(2), today: today, roll: .future) else { return nil }
            return CalcResult(value: "\(abs(end - start)) days", detail: "\(start.formatted) → \(end.formatted)", kind: .date)
        }

        if let match = weeksUntil.firstMatch(in: text) {
            guard let target = DateTokens.parse(match.text(1), today: today, roll: .future) else { return nil }
            let weeks = (Double(target - today) / 7 * 10).rounded() / 10
            return CalcResult(value: "\(CalcFormat.plain(weeks)) weeks", detail: target.formatted, kind: .date)
        }

        if let match = weekdayInWeeks.firstMatch(in: text) {
            guard let weekday = DateTokens.weekdayFromMonday(match.text(1)),
                  let count = boundedCount(match.text(2)) else { return nil }
            let base = today.adding(days: count * 7)
            let monday = base.adding(days: -base.weekdayFromMonday)
            return dateResult(monday.adding(days: weekday), today: today)
        }

        if let match = inCount.firstMatch(in: text) ?? countFromNow.firstMatch(in: text) {
            guard let count = boundedCount(match.text(1)),
                  let target = add(count, unit: match.text(2), to: today) else { return nil }
            return dateResult(target, today: today)
        }

        if let match = countAgo.firstMatch(in: text) {
            guard let count = boundedCount(match.text(1)),
                  let target = add(-count, unit: match.text(2), to: today) else { return nil }
            var result = dateResult(target, today: today)
            result.detail = "\(count) \(match.text(2).lowercased()) ago"
            return result
        }

        if let match = workInYear.firstMatch(in: text) {
            guard let year = Int(match.text(2)) else { return nil }
            return workTime(in: year, hours: match.text(1).lowercased() == "hours")
        }

        if let match = nextWeekday.firstMatch(in: text) {
            guard let target = DateTokens.parse(match.text(0), today: today, roll: .future) else { return nil }
            return dateResult(target, today: today)
        }

        if let match = clock.firstMatch(in: text) {
            return clockArithmetic(match)
        }

        if let match = dateArithmetic.firstMatch(in: text) {
            guard let base = DateTokens.parse(match.text(1), today: today, roll: .future),
                  let count = boundedCount(match.text(3)) else { return nil }
            let sign = match.text(2)
            let unit = match[4] ?? "days"
            guard let target = add(sign == "-" ? -count : count, unit: unit, to: base) else { return nil }
            var result = dateResult(target, today: today)
            result.detail = "\(base.formatted) \(sign) \(count) \(unit)"
            return result
        }

        return nil
    }

    /// `3:45pm + 90 minutes`. Requires am/pm or minutes so plain math like `2 + 2` is skipped.
    private static func clockArithmetic(_ match: RegexMatch) -> CalcResult? {
        guard match[2] != nil || match[3] != nil,
              let minutesIntoDay = WallClock.minutesIntoDay(hour: match.text(1), minute: match[2], meridiem: match[3]),
              let count = Int(match.text(5)) else { return nil }
        let isMinutes = match[6]?.lowercased().hasPrefix("m") ?? false
        let unitMinutes = isMinutes ? 1 : 60
        let sign = match.text(4) == "+" ? 1 : -1
        // Reduced modulo one day first so a huge count can't overflow.
        let offset = (count % 1440) * unitMinutes % 1440
        let total = ((minutesIntoDay + sign * offset) % 1440 + 1440) % 1440
        let whole = match.text(0)
        let start = whole[..<(whole.firstIndex { $0 == "+" || $0 == "-" } ?? whole.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return CalcResult(
            value: WallClock.twelveHour(minutesIntoDay: total),
            detail: "\(start) \(match.text(4)) \(count) \(isMinutes ? "min" : "h")",
            kind: .time
        )
    }

    private static func workTime(in year: Int, hours: Bool) -> CalcResult? {
        guard let start = CivilDate(year: year, month: 1, day: 1),
              let end = CivilDate(year: year + 1, month: 1, day: 1) else { return nil }
        let workdays = (0..<(end - start)).filter { !start.adding(days: $0).isWeekend }.count
        if hours {
            return CalcResult(
                value: "\(CalcFormat.groupThousands(String(workdays * 8))) h",
                detail: "\(workdays) workdays × 8 h in \(year)",
                kind: .date
            )
        }
        return CalcResult(value: "\(workdays) workdays", detail: "Mon–Fri days in \(year)", kind: .date)
    }

    private static func add(_ count: Int, unit: String, to date: CivilDate) -> CivilDate? {
        let unit = unit.lowercased()
        if unit.hasPrefix("day") { return date.adding(days: count) }
        if unit.hasPrefix("week") { return date.adding(days: count * 7) }
        if unit.hasPrefix("month") { return date.adding(months: count) }
        if unit.hasPrefix("year") { return date.adding(months: count * 12) }
        return nil
    }

    private static func dateResult(_ target: CivilDate, today: CivilDate) -> CalcResult {
        let days = target - today
        let detail = switch days {
        case 0: "today"
        case 1: "tomorrow"
        case 1...: "in \(days) days"
        default: "\(-days) days ago"
        }
        return CalcResult(value: target.formatted, detail: detail, kind: .date)
    }

    /// A count small enough that date arithmetic can't overflow.
    private static func boundedCount(_ text: String) -> Int? {
        guard let count = Int(text), count <= 10_000_000 else { return nil }
        return count
    }
}

/// Shared 12/24-hour clock helpers for date and world-clock phrases.
enum WallClock {
    /// `3`, `45`, `pm` → minutes since midnight, or `nil` for an impossible time.
    static func minutesIntoDay(hour hourText: String, minute minuteText: String?, meridiem: String?) -> Int? {
        guard var hour = Int(hourText), let minute = Int(minuteText ?? "0"), hour <= 23, minute <= 59 else {
            return nil
        }
        if let meridiem {
            guard hour <= 12 else { return nil }
            let isPM = meridiem.lowercased() == "pm"
            hour = switch (hour, isPM) {
            case (12, false): 0
            case (12, true): 12
            case (_, true): hour + 12
            case (_, false): hour
            }
        }
        return hour * 60 + minute
    }

    /// `8:45 PM`.
    static func twelveHour(minutesIntoDay: Int) -> String {
        let hour = minutesIntoDay / 60, minute = minutesIntoDay % 60
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minute, hour < 12 ? "AM" : "PM")
    }
}
