import AppKit
import SwiftUI

/// The app's version and where to find its source, releases and issues.
struct AboutView: View {
    private static let repository = URL(string: "https://github.com/tahsinature/tooki")!
    private static let installCommand = "brew install --cask tahsinature/tap/tooki"

    private var version: String {
        let channel = BuildInfo.isRelease ? "" : " · Dev build \(BuildInfo.commit)"
        return "Version \(BuildInfo.version) (\(BuildInfo.build))\(channel)"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    Text("Tooki").font(.title2.bold())
                    Text(version)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section("Links") {
                link("Source Code", symbol: "chevron.left.forwardslash.chevron.right", path: "")
                link("Release Notes", symbol: "sparkles", path: "/releases")
                link("Report an Issue", symbol: "ladybug", path: "/issues/new")
            }

            Section {
                LabeledContent("Homebrew") {
                    Text(Self.installCommand)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            } header: {
                Text("Install")
            } footer: {
                Text("Run `brew trust tahsinature/tap` first on a new Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func link(_ title: String, symbol: String, path: String) -> some View {
        Link(destination: Self.repository.appending(path: path)) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
