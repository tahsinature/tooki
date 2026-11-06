import SwiftUI

/// Keeps the packaging age current, with the exact time and commit available on hover.
struct BuildTimestamp: View {
    let prefix: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text("\(prefix) · \(BuildInfo.buildTimeLabel(relativeTo: context.date))")
        }
        .help(details)
    }

    private var details: String {
        let timestamp = BuildInfo.builtAt?.formatted(date: .complete, time: .standard) ?? "Time unavailable"
        let commit = BuildInfo.isRelease || BuildInfo.commit.isEmpty ? "" : " · \(BuildInfo.commit)"
        return "\(BuildInfo.isRelease ? "Release" : "Dev")\(commit) · \(timestamp)"
    }
}
