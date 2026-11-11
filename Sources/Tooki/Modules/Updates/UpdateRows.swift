import SwiftUI
import TookiKit

/// About > Updates: check, install or skip at any time. Rows for the About page's updates card.
struct UpdateRows: View {
    let updater: Updater
    @Bindable var config: JSONDocument<TookiConfig>

    var body: some View {
        if updater.isEnabled {
            status
            if let release = updater.availableRelease {
                SettingsRow("Release notes") {
                    Link("View on GitHub ↗", destination: release.pageURL)
                }
            }
            SettingsToggleRow("Check for updates automatically", isOn: $config.value.updates.checkAutomatically)
        } else {
            SettingsRow("Updates") {
                Text("Off in dev builds").foregroundStyle(SettingsTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.state {
        case .available(let release):
            SettingsRow("Version \(release.version) is available") {
                HStack {
                    if release.version != updater.skippedVersion {
                        Button("Skip", action: updater.skip)
                    }
                    Button("Install and Restart", action: updater.install)
                        .buttonStyle(.borderedProminent)
                }
            }
        case .installing(let release):
            SettingsRow("Installing version \(release.version)…") {
                ProgressView().controlSize(.small)
            }
        case .checking:
            SettingsRow("Checking for updates…") {
                ProgressView().controlSize(.small)
            }
        case .failed(let message):
            SettingsRow(message) {
                Button("Try Again", action: updater.check)
            }
        case .idle, .upToDate:
            SettingsRow(updater.state == .upToDate ? "Tooki is up to date" : "Not checked yet") {
                HStack {
                    if let lastChecked = updater.lastChecked {
                        Text("Checked \(lastChecked, format: .relative(presentation: .named))")
                            .foregroundStyle(SettingsTheme.secondaryText)
                    }
                    Button("Check Now", action: updater.check)
                }
            }
        }
    }
}
