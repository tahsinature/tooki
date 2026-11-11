import Foundation

/// World-clock queries: `time in tokyo`, `5pm ldn in sf`, `time diff paris`,
/// `time in 4 hours`, `3pm est in pst`.
enum WorldClockPhrases {
    private static let relative = RegexPattern(#"(?i)^time\s+in\s+(\d+)\s+(hours?|hrs?|minutes?|mins?)(?:\s+in\s+(.+))?$"#)
    private static let inCity = RegexPattern(#"(?i)^time\s+in\s+(.+)$"#)
    private static let citySuffix = RegexPattern(#"(?i)^(.+?)\s+time$"#)
    private static let difference = RegexPattern(#"(?i)^(?:time\s+)?diff\s+(.+)$"#)
    private static let wallTime = RegexPattern(#"(?i)^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(.+?)(?:\s+(?:in|to)\s+(.+))?$"#)

    /// Evaluates a time-zone query against an injected clock and local zone.
    static func evaluate(_ query: String, now: Date, localZone: WorldZone) -> CalcResult? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // `time in 4 hours [in tokyo]` must run before the city match.
        if let match = relative.firstMatch(in: text) {
            guard let count = Int(match.text(1)), count <= 10_000_000 else { return nil }
            let unitSeconds = match.text(2).lowercased().hasPrefix("m") ? 60 : 3600
            let zone: WorldZone
            if let city = match[3] {
                guard let resolved = ZoneNames.resolve(city) else { return nil }
                zone = resolved
            } else {
                zone = localZone
            }
            let later = LocalTime(now.addingTimeInterval(Double(count * unitSeconds)), in: zone)
            return CalcResult(value: later.clock, detail: "\(later.date.formattedWithoutYear) · in \(zone.shortName)", kind: .time)
        }

        if let match = inCity.firstMatch(in: text) {
            guard let zone = ZoneNames.resolve(match.text(1)) else { return nil }
            return cityResult(zone, now: now)
        }

        // Falls through when the prefix isn't a city ("2+2 time").
        if let match = citySuffix.firstMatch(in: text), let zone = ZoneNames.resolve(match.text(1)) {
            return cityResult(zone, now: now)
        }

        if let match = difference.firstMatch(in: text) {
            guard let zone = ZoneNames.resolve(match.text(1)) else { return nil }
            return differenceResult(zone, now: now, localZone: localZone)
        }

        if let match = wallTime.firstMatch(in: text) {
            return wallTimeConversion(match, now: now, localZone: localZone)
        }

        return nil
    }

    private static func cityResult(_ zone: WorldZone, now: Date) -> CalcResult {
        let local = LocalTime(now, in: zone)
        let offset = offsetText(zone.secondsFromGMT(at: now))
        return CalcResult(
            value: local.clock,
            detail: "\(local.date.formattedWithoutYear) · \(zone.identifier) (UTC\(offset))",
            kind: .time
        )
    }

    private static func differenceResult(_ zone: WorldZone, now: Date, localZone: WorldZone) -> CalcResult {
        let deltaMinutes = (zone.secondsFromGMT(at: now) - localZone.secondsFromGMT(at: now)) / 60
        let value: String
        if deltaMinutes == 0 {
            value = "same time"
        } else {
            let hours = abs(deltaMinutes) / 60, minutes = abs(deltaMinutes) % 60
            let span = minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
            value = "\(span) \(deltaMinutes > 0 ? "ahead" : "behind")"
        }
        let there = LocalTime(now, in: zone).clock
        let here = LocalTime(now, in: localZone).clock
        return CalcResult(value: value, detail: "\(zone.shortName) \(there) · \(here) here", kind: .time)
    }

    /// `5pm ldn in sf`: a wall time in one zone shown in another (the local zone by default).
    private static func wallTimeConversion(_ match: RegexMatch, now: Date, localZone: WorldZone) -> CalcResult? {
        // Requiring am/pm or minutes keeps `100 usd in eur` from matching.
        guard match[2] != nil || match[3] != nil,
              let minutesIntoDay = WallClock.minutesIntoDay(hour: match.text(1), minute: match[2], meridiem: match[3]),
              let source = ZoneNames.resolve(match.text(4)) else { return nil }
        let target: WorldZone
        if let targetName = match[5] {
            guard let resolved = ZoneNames.resolve(targetName) else { return nil }
            target = resolved
        } else {
            target = localZone
        }
        let sourceDate = LocalTime(now, in: source).date
        guard let instant = LocalTime.earliestInstant(date: sourceDate, minutesIntoDay: minutesIntoDay, in: source) else {
            return nil
        }
        return CalcResult(
            value: LocalTime(instant, in: target).clock,
            detail: "\(WallClock.twelveHour(minutesIntoDay: minutesIntoDay)) \(source.shortName) → \(target.shortName)",
            kind: .time
        )
    }

    /// `+9`, `+5:45`, `-7:30`.
    private static func offsetText(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        return minutes == 0 ? "\(sign)\(hours)" : String(format: "%@%d:%02d", sign, hours, minutes)
    }
}

/// The wall-clock date and time an instant shows in a zone.
struct LocalTime {
    let date: CivilDate
    let minutesIntoDay: Int

    init(_ instant: Date, in zone: WorldZone) {
        let localSeconds = Int(instant.timeIntervalSince1970.rounded(.down)) + zone.secondsFromGMT(at: instant)
        let days = Int((Double(localSeconds) / 86_400).rounded(.down))
        date = CivilDate(daysSinceEpoch: days)
        minutesIntoDay = (localSeconds - days * 86_400) / 60
    }

    /// `21:00`.
    var clock: String {
        String(format: "%02d:%02d", minutesIntoDay / 60, minutesIntoDay % 60)
    }

    /// The earliest instant showing this wall time in `zone`, or `nil` when
    /// the time falls into a DST gap (like chrono's `from_local_datetime(..).earliest()`).
    static func earliestInstant(date: CivilDate, minutesIntoDay: Int, in zone: WorldZone) -> Date? {
        let wallSeconds = Double(date.daysSinceEpoch * 86_400 + minutesIntoDay * 60)
        let nearbyOffsets = Set([-86_400.0, 0, 86_400].map { zone.secondsFromGMT(at: Date(timeIntervalSince1970: wallSeconds + $0)) })
        let candidates = nearbyOffsets
            .map { Date(timeIntervalSince1970: wallSeconds - Double($0)) }
            .filter { Double(zone.secondsFromGMT(at: $0)) == wallSeconds - $0.timeIntervalSince1970 }
        return candidates.min()
    }
}
