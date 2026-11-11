import Foundation

/// A calendar date without a time or zone, like chrono's `NaiveDate`.
/// Stored as days since 1970-01-01 so date arithmetic is plain integer math.
struct CivilDate: Comparable, Hashable, Sendable {
    let daysSinceEpoch: Int

    private static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    init(daysSinceEpoch: Int) {
        self.daysSinceEpoch = daysSinceEpoch
    }

    /// chrono's supported year range, which also keeps the day math far from overflow.
    static let supportedYears = -262_143...262_142

    /// `nil` for dates that don't exist, such as Feb 29 in a common year.
    init?(year: Int, month: Int, day: Int) {
        guard Self.supportedYears.contains(year), (1...12).contains(month), day >= 1, day <= Self.daysInMonth(year: year, month: month) else {
            return nil
        }
        daysSinceEpoch = Self.daysFromCivil(year: year, month: month, day: day)
    }

    /// Today's date in `timeZone` at the instant `now`.
    init(now: Date, timeZone: TimeZone) {
        let localSeconds = now.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: now))
        daysSinceEpoch = Int((localSeconds / 86_400).rounded(.down))
    }

    var components: (year: Int, month: Int, day: Int) {
        Self.civilFromDays(daysSinceEpoch)
    }

    var year: Int { components.year }

    /// 0 for Monday through 6 for Sunday. 1970-01-01 was a Thursday.
    var weekdayFromMonday: Int {
        ((daysSinceEpoch + 3) % 7 + 7) % 7
    }

    var isWeekend: Bool { weekdayFromMonday >= 5 }

    /// `Sat, 11 Jul 2026`.
    var formatted: String {
        "\(formattedWithoutYear) \(year)"
    }

    /// `Sat, 11 Jul`.
    var formattedWithoutYear: String {
        let (_, month, day) = components
        return "\(Self.weekdayNames[weekdayFromMonday]), \(day) \(Self.monthNames[month - 1])"
    }

    func adding(days: Int) -> CivilDate {
        CivilDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// Calendar-aware month arithmetic that clamps to the month's last day
    /// (Jan 31 + 1 month = Feb 28), like chrono's `checked_add_months`.
    func adding(months: Int) -> CivilDate? {
        let (year, month, day) = components
        let monthIndex = year * 12 + (month - 1) + months
        let newYear = Int((Double(monthIndex) / 12).rounded(.down))
        let newMonth = monthIndex - newYear * 12 + 1
        let clampedDay = min(day, Self.daysInMonth(year: newYear, month: newMonth))
        return CivilDate(year: newYear, month: newMonth, day: clampedDay)
    }

    static func - (lhs: CivilDate, rhs: CivilDate) -> Int {
        lhs.daysSinceEpoch - rhs.daysSinceEpoch
    }

    static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        lhs.daysSinceEpoch < rhs.daysSinceEpoch
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    // Howard Hinnant's days_from_civil / civil_from_days algorithms.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let shifted = days + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}
