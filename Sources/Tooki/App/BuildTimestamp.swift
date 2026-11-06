import SwiftUI

/// Keeps the packaging age current, with the exact time and commit available on hover.
struct BuildTimestamp: View {
    let prefix: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text("\(prefix) · \(BuildInfo.buildTimeLabel(relativeTo: context.date))")
        }
        .help(BuildInfo.details)
    }
}
