import SwiftUI
import TookiKit

/// About > Updates: check, install or skip at any time.
struct UpdatesSection: View {
    let updater: Updater
    @Bindable var config: JSONDocument<TookiConfig>

    var body: some View {
        Section("Updates") {
            if updater.isEnabled {
                status
                if let release = updater.availableRelease {
                    LabeledContent("Release notes") {
                        Link("View on GitHub ↗", destination: release.pageURL)
                    }
                }
                Toggle("Check for updates automatically", isOn: $config.value.updates.checkAutomatically)
            } else {
                LabeledContent("Updates", value: "Off in dev builds")
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.state {
        case .available(let release):
            LabeledContent("Version \(release.version) is available") {
                HStack {
                    if release.version != updater.skippedVersion {
                        Button("Skip", action: updater.skip)
                    }
                    Button("Install and Restart", action: updater.install)
                        .buttonStyle(.borderedProminent)
                }
            }
        case .installing(let release):
            LabeledContent("Installing version \(release.version)…") {
                ProgressView().controlSize(.small)
            }
        case .checking:
            LabeledContent("Checking for updates…") {
                ProgressView().controlSize(.small)
            }
        case .failed(let message):
            LabeledContent(message) {
                Button("Try Again", action: updater.check)
            }
        case .idle, .upToDate:
            LabeledContent(updater.state == .upToDate ? "Tooki is up to date" : "Not checked yet") {
                HStack {
                    if let lastChecked = updater.lastChecked {
                        Text("Checked \(lastChecked, format: .relative(presentation: .named))")
                            .foregroundStyle(.secondary)
                    }
                    Button("Check Now", action: updater.check)
                }
            }
        }
    }
}
