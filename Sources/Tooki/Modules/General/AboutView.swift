import AppKit
import SwiftUI
import TookiKit

/// The app's version and updates, who made it, and where to find its source, releases and issues.
/// Laid out like Asyar's About tab.
struct AboutView: View {
    let updater: Updater
    @Bindable var config: JSONDocument<TookiConfig>
    @Environment(\.openURL) private var openURL
    private static let repository = URL(string: "https://github.com/tahsinature/tooki")!
    private static let installCommand = "brew install --cask tahsinature/tap/tooki"

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
                SettingsRow("Project links", description: "Source code, release notes and the issue tracker.") {
                    HStack(spacing: 6) {
                        link("Source Code", symbol: "chevron.left.forwardslash.chevron.right", path: "")
                        link("Release Notes", symbol: "sparkles", path: "/releases")
                        link("Report an Issue", symbol: "ladybug", path: "/issues/new")
                    }
                }
            }

            SettingsSection("Install") {
                // The command is too long to share a line with the title, so it sits below it.
                SettingsCardRow {
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsRowLabel(title: "Homebrew")
                        HStack(spacing: 8) {
                            Text(Self.installCommand)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(SettingsTheme.primaryText)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Copy", systemImage: "doc.on.doc") { Paster.copy(Self.installCommand) }
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                        .background(SettingsTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: SettingsTheme.controlRadius))
                    }
                }
            } footer: {
                Text("Run `brew trust tahsinature/tap` first on a new Mac.")
            }
        }
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
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
                .frame(width: 72, height: 72)
            Text(BuildInfo.appName)
                .font(.system(size: 15, weight: .bold))
                .padding(.top, 8)
            BuildTimestamp(prefix: version)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.secondaryText)
                .textSelection(.enabled)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}
