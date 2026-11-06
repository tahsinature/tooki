import SwiftUI

/// A compact version or development indicator for the sidebar.
struct BuildLabel: View {
    var body: some View {
        BuildTimestamp(prefix: BuildInfo.isRelease ? "Version \(BuildInfo.version)" : "Dev")
            .font(.caption)
            .foregroundStyle(BuildInfo.isRelease ? Color.secondary : .orange)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}
