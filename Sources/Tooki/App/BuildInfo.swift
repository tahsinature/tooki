import Foundation
import SwiftUI

/// Which build is running. `make app` marks builds as dev; the release workflow marks them as release.
enum BuildInfo {
    static let version = value("CFBundleShortVersionString") ?? "?"
    static let build = value("CFBundleVersion") ?? "?"
    /// The git commit a dev build was made from, ending in "-dirty" when it had uncommitted changes.
    static let commit = value("TookiCommit") ?? ""
    static let isRelease = value("TookiBuildChannel") == "release"

    private static func value(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

/// A one-line build description: the plain version on releases, an orange "Dev · <commit>" on local builds.
struct BuildLabel: View {
    var body: some View {
        if BuildInfo.isRelease {
            Text("Version \(BuildInfo.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(devLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .help("Development build. Releases show their version here instead.")
        }
    }

    private var devLabel: String {
        guard !BuildInfo.commit.isEmpty else { return "Dev build" }
        let isDirty = BuildInfo.commit.hasSuffix("-dirty")
        let hash = BuildInfo.commit.replacingOccurrences(of: "-dirty", with: "")
        return "Dev · \(hash)\(isDirty ? " •" : "")"
    }
}
