import Foundation

/// Which build is running. `make app` marks builds as dev; the release workflow marks them as release.
enum BuildInfo {
    static let appName = value("CFBundleDisplayName") ?? "Tooki"
    static let version = value("CFBundleShortVersionString") ?? "?"
    static let build = value("CFBundleVersion") ?? "?"
    /// The git commit a dev build was made from, ending in "-dirty" when it had uncommitted changes.
    static let commit = value("TookiCommit") ?? ""
    static let isRelease = value("TookiBuildChannel") == "release"
    /// Packaging time, shared by every build indicator.
    static let builtAt = value("TookiBuiltAt").flatMap { ISO8601DateFormatter().date(from: $0) }

    static func buildTimeLabel(relativeTo date: Date) -> String {
        guard let builtAt else { return "Time unavailable" }
        guard date.timeIntervalSince(builtAt) >= 60 else { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short
        return formatter.localizedString(for: builtAt, relativeTo: date)
    }

    private static func value(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
