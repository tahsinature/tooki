import AppKit

/// Name and icon of the app an item was copied from. Lookups are cached.
@MainActor
struct SourceApp {
    let name: String
    let icon: NSImage?

    private static var cache: [String: SourceApp?] = [:]

    static func named(_ bundleID: String?) -> SourceApp? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { url in
            SourceApp(
                name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                icon: NSWorkspace.shared.icon(forFile: url.path)
            )
        }
        cache[bundleID] = app
        return app
    }
}
