import AppKit
import Observation
import TookiKit

/// A release on GitHub that's newer than the running Tooki.
struct AppRelease: Equatable, Sendable {
    let version: String
    let pageURL: URL
    let dmgURL: URL
}

/// Checks GitHub for a newer release and installs it. Only release builds update themselves,
/// so a local dev build is never replaced.
@MainActor
@Observable
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case installing(AppRelease)
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var lastChecked: Date?
    /// "Skip" hides the sidebar prompt for this version; About still offers it.
    private(set) var skippedVersion = UserDefaults.standard.string(forKey: DefaultsKey.skippedVersion)

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var checksAutomatically = false

    private static let checkInterval: TimeInterval = 24 * 60 * 60
    /// `defaults write com.mohammadtahsin.tooki updateFeedURL <url>` points Tooki at another release, for testing.
    private static var feedURL: URL {
        UserDefaults.standard.string(forKey: DefaultsKey.feedURL).flatMap(URL.init(string:))
            ?? URL(string: "https://api.github.com/repos/tahsinature/tooki/releases/latest")!
    }

    private enum DefaultsKey {
        static let skippedVersion = "skippedUpdateVersion"
        static let feedURL = "updateFeedURL"
    }

    var isEnabled: Bool { BuildInfo.isRelease }

    var availableRelease: AppRelease? {
        if case .available(let release) = state { return release }
        return nil
    }

    /// Whether the sidebar shows the Update pill.
    var shouldPrompt: Bool {
        guard let availableRelease else { return false }
        return availableRelease.version != skippedVersion
    }

    func setChecksAutomatically(_ enabled: Bool) {
        guard isEnabled, enabled != checksAutomatically else { return }
        checksAutomatically = enabled
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func check() {
        switch state {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        Task {
            do {
                let release = try await Self.fetchLatest()
                lastChecked = .now
                state = AppVersion.isNewer(release.version, than: BuildInfo.version) ? .available(release) : .upToDate
            } catch {
                state = .failed("Couldn't check for updates")
            }
        }
    }

    func skip() {
        guard let availableRelease else { return }
        skippedVersion = availableRelease.version
        UserDefaults.standard.set(availableRelease.version, forKey: DefaultsKey.skippedVersion)
    }

    func install() {
        guard let release = availableRelease else { return }
        state = .installing(release)
        Task {
            do {
                try await UpdateInstaller.install(release)
                NSApp.terminate(nil)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private static func fetchLatest() async throws -> AppRelease {
        var request = URLRequest(url: feedURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let latest = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let dmg = latest.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
            throw URLError(.resourceUnavailable)
        }
        return AppRelease(
            version: AppVersion.plain(latest.tagName),
            pageURL: latest.htmlURL,
            dmgURL: dmg.browserDownloadURL
        )
    }
}

/// The parts of GitHub's "latest release" response that Tooki uses.
private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
