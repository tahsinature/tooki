import AppKit

/// An app the launcher can open.
struct InstalledApp: Sendable {
    let name: String
    let url: URL
}

/// Finds installed apps, like Spotlight's "Applications" results.
@MainActor
final class AppCatalog {
    private(set) var apps: [InstalledApp] = []
    private let icons = NSCache<NSURL, NSImage>()

    nonisolated private static let folders = [
        "/Applications",
        "/System/Applications",
        "/System/Library/CoreServices/Applications",
        "~/Applications",
    ]

    /// Scans in the background. Cheap enough to repeat each time the launcher opens.
    func refresh() async {
        apps = await Task.detached(priority: .userInitiated) { Self.scan() }.value
    }

    func icon(for app: InstalledApp) -> NSImage {
        if let cached = icons.object(forKey: app.url as NSURL) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: app.url.path)
        icon.size = CGSize(width: 32, height: 32)
        icons.setObject(icon, forKey: app.url as NSURL)
        return icon
    }

    nonisolated private static func scan() -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for folder in folders {
            let url = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath)
            for appURL in appBundles(in: url, depth: 2) where seen.insert(appURL.lastPathComponent).inserted {
                let name = FileManager.default.displayName(atPath: appURL.path)
                apps.append(InstalledApp(name: (name as NSString).deletingPathExtension, url: appURL))
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Looks inside plain folders such as `/Applications/Utilities`, but never inside an app.
    nonisolated private static func appBundles(in folder: URL, depth: Int) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.flatMap { url -> [URL] in
            if url.pathExtension == "app" { return [url] }
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            return isFolder && depth > 1 ? appBundles(in: url, depth: depth - 1) : []
        }
    }
}
