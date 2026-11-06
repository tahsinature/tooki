import AppKit

/// Keeps one Tooki running across production and development builds, which share storage and shortcuts.
@MainActor
enum SingleInstance {
    static func replaceOlderCopies() async {
        let current = NSRunningApplication.current
        let bundleIDs = ["com.mohammadtahsin.tooki", "com.mohammadtahsin.tooki.dev"]
        let olderCopies = bundleIDs.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .filter { $0.processIdentifier != current.processIdentifier }
        guard !olderCopies.isEmpty else { return }

        olderCopies.forEach { $0.terminate() }
        for _ in 0..<30 where olderCopies.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        olderCopies.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    }

    /// Installed releases from before the dev identity existed cannot close the dev app themselves.
    static func quitIfProductionIsRunning() {
        guard NSRunningApplication.current.bundleIdentifier == "com.mohammadtahsin.tooki.dev" else { return }
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohammadtahsin.tooki").isEmpty {
            NSApp.terminate(nil)
        }
    }
}
