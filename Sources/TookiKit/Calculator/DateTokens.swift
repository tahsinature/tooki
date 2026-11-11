import Foundation

/// Parses a single natural date such as `today`, `2026-08-05`, `aug 5`,
/// `31 march 2027`, `christmas` or `next friday`.
enum DateTokens {
    private static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]
    private static let isoDate = RegexPattern(#"^(\d{4,6})-(\d{1,2})-(\d{1,2})$"#)

    private static let holidays: [String: (month: Int, day: Int)] = [
        "christmas": (12, 25), "christmas day": (12, 25), "xmas": (12, 25),
        "christmas eve": (12, 24),
        "new year": (1, 1), "new years": (1, 1), "new year's": (1, 1),
        "new year's day": (1, 1), "new years day": (1, 1),
        "new year's eve": (12, 31), "new years eve": (12, 31),
        "halloween": (10, 31),
        "valentine's day": (2, 14), "valentines day": (2, 14),
        "valentine's": (2, 14), "valentines": (2, 14),
    ]

    static func parse(_ token: String, today: CivilDate, roll: DatePhrases.Roll) -> CivilDate? {
        var text = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("the ") {
            text = String(text.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch text {
        case "today", "now": return today
        case "tomorrow": return today.adding(days: 1)
        case "yesterday": return today.adding(days: -1)
        default: break
        }

        if let match = isoDate.firstMatch(in: text) {
            return CivilDate(year: Int(match.text(1)) ?? 0, month: Int(match.text(2)) ?? 0, day: Int(match.text(3)) ?? 0)
        }

        if let holiday = holidays[text] {
            return rolled(month: holiday.month, day: holiday.day, today: today, roll: roll)
        }

        if let weekday = weekdayFromMonday(withoutPrefix(text, "next ", "this ")) {
            let daysAhead = ((weekday - today.weekdayFromMonday) % 7 + 7) % 7
            let nextOccurrence = today.adding(days: daysAhead == 0 ? 7 : daysAhead)
            return roll == .future ? nextOccurrence : nextOccurrence.adding(days: -7)
        }

        return monthDay(text, today: today, roll: roll)
    }

    /// 0 for Monday through 6 for Sunday.
    static func weekdayFromMonday(_ name: String) -> Int? {
        switch name.lowercased() {
        case "monday", "mon": 0
        case "tuesday", "tue", "tues": 1
        case "wednesday", "wed": 2
        case "thursday", "thu", "thur", "thurs": 3
        case "friday", "fri": 4
        case "saturday", "sat": 5
        case "sunday", "sun": 6
        default: nil
        }
    }

    /// `aug 5`, `5 aug`, `march 31 2027`, `31 march, 2027`.
    private static func monthDay(_ text: String, today: CivilDate, roll: DatePhrases.Roll) -> CivilDate? {
        let parts = text.replacingOccurrences(of: ",", with: " ").split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        var year: Int?
        if parts.count == 3 {
            guard let parsedYear = Int(parts[2]) else { return nil }
            year = parsedYear
        }

        let month: Int
        let dayText: String
        if let leadingMonth = monthNumber(named: parts[0]) {
            (month, dayText) = (leadingMonth, parts[1])
        } else {
            guard let trailingMonth = monthNumber(named: parts[1]) else { return nil }
            (month, dayText) = (trailingMonth, parts[0])
        }
        guard let day = Int(strippingOrdinal(dayText)) else { return nil }

        if let year {
            return CivilDate(year: year, month: month, day: day)
        }
        return rolled(month: month, day: day, today: today, roll: roll)
    }

    /// 1-based month for a full name or a prefix of at least 3 letters.
    private static func monthNumber(named name: String) -> Int? {
        let name = name.lowercased()
        let index = monthNames.firstIndex { $0 == name || (name.count >= 3 && $0.hasPrefix(name)) }
        return index.map { $0 + 1 }
    }

    /// Picks the closest year in the roll direction where the date exists.
    /// Feb 29 may need up to 4 years of searching.
    private static func rolled(month: Int, day: Int, today: CivilDate, roll: DatePhrases.Roll) -> CivilDate? {
        for offset in 0...4 {
            let year = roll == .future ? today.year + offset : today.year - offset
            guard let date = CivilDate(year: year, month: month, day: day) else { continue }
            if roll == .future ? date >= today : date <= today {
                return date
            }
        }
        return nil
    }

    /// `5th` → `5`. Leaves anything that isn't digits plus an ordinal suffix unchanged.
    private static func strippingOrdinal(_ text: String) -> String {
        for suffix in ["st", "nd", "rd", "th"] where text.hasSuffix(suffix) {
            let digits = text.dropLast(2)
            return !digits.isEmpty && digits.allSatisfy(\.isASCIIDigit) ? String(digits) : text
        }
        return text
    }

    private static func withoutPrefix(_ text: String, _ prefixes: String...) -> String {
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }
}
