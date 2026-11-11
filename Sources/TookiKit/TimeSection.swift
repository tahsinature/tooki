import Foundation

/// The day group a list entry (a clipboard item, a snippet) is listed under, like Asyar's clipboard history.
/// Cases are in display order, newest first.
public enum TimeSection: String, CaseIterable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"

    public init(of date: Date, now: Date = Date(), calendar: Calendar = .current) {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 0 {
            self = .today
        } else if days == 1 {
            self = .yesterday
        } else if days < 7 {
            self = .thisWeek
        } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            self = .thisMonth
        } else {
            self = .older
        }
    }
}
