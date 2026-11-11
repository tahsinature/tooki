import AppKit
import UniformTypeIdentifiers

/// An app that can open something, for an "Open With" list.
struct OpenWithApp {
    let url: URL
    let name: String
    let icon: NSImage
    let isDefault: Bool
}

/// Lists apps that can open a URL or a type of file, the default one first, then the rest by name,
/// like Finder's Open With.
@MainActor
enum OpenWithApps {
    static func apps(toOpen url: URL) -> [OpenWithApp] {
        let workspace = NSWorkspace.shared
        return list(default: workspace.urlForApplication(toOpen: url), all: workspace.urlsForApplications(toOpen: url))
    }

    static func apps(toOpen type: UTType) -> [OpenWithApp] {
        let workspace = NSWorkspace.shared
        return list(default: workspace.urlForApplication(toOpen: type), all: workspace.urlsForApplications(toOpen: type))
    }

    private static func list(default defaultApp: URL?, all: [URL]) -> [OpenWithApp] {
        let others = all
            .filter { $0 != defaultApp }
            .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }
        // The same app can be installed twice, e.g. in /Applications and ~/Applications.
        var seenNames = Set<String>()
        return ([defaultApp].compactMap { $0 } + others).compactMap { url in
            let name = name(of: url)
            guard seenNames.insert(name).inserted else { return nil }
            return OpenWithApp(url: url, name: name, icon: NSWorkspace.shared.icon(forFile: url.path), isDefault: url == defaultApp)
        }
    }

    private static func name(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path).replacing(".app", with: "")
    }
}
