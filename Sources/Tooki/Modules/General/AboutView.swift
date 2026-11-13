import AppKit
import SwiftUI
import TookiKit

/// The app's version and updates, who made it, and where to find its source, releases and issues.
struct AboutView: View {
    let updater: Updater
    @Bindable var config: JSONDocument<TookiConfig>
    @Environment(\.openURL) private var openURL
    private static let repository = URL(string: "https://github.com/tahsinature/tooki")!

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Updates") {
                SettingsCardRow { AboutAppHeader() }
                UpdateRows(updater: updater, config: config)
            }

            SettingsSection("Credits") {
                SettingsRow("Created by") { infoText("Tahsin") }
                SettingsRow("Built with") { infoText("Swift, SwiftUI, AppKit") }
            }

            SettingsSection("Links") {
                SettingsCardRow {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsRowLabel(title: "Project links", description: "Source code, release notes and the issue tracker.")
                        HStack(spacing: 6) {
                            link("Source Code", symbol: "chevron.left.forwardslash.chevron.right", path: "")
                            link("Release Notes", symbol: "sparkles", path: "/releases")
                            link("Report an Issue", symbol: "ladybug", path: "/issues/new")
                        }
                    }
                }
            }
        }
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(SettingsTheme.controlFont)
            .foregroundStyle(SettingsTheme.primaryText)
    }

    private func link(_ title: String, symbol: String, path: String) -> some View {
        Button(title, systemImage: symbol) {
            openURL(Self.repository.appending(path: path))
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// The centered app icon, name and version at the top of the updates card.
private struct AboutAppHeader: View {
    private var version: String {
        let channel = BuildInfo.isRelease ? "" : " · Dev \(BuildInfo.commit)"
        return "Version \(BuildInfo.version) (\(BuildInfo.build))\(channel)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
            Text(BuildInfo.appName)
                .font(SettingsTheme.font(13, weight: .medium))
                .padding(.top, 8)
            BuildTimestamp(prefix: version)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(SettingsTheme.controlFont)
                .foregroundStyle(SettingsTheme.secondaryText)
                .textSelection(.enabled)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}
