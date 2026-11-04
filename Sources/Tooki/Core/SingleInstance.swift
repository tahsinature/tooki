import AppKit

/// Keeps one Tooki running. A new launch quits any older copy first,
/// so `make run` replaces the installed app instead of adding a second menu bar icon.
@MainActor
enum SingleInstance {
    static func replaceOlderCopies() async {
        let current = NSRunningApplication.current
        guard let bundleID = current.bundleIdentifier else { return }
        let olderCopies = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != current.processIdentifier }
        guard !olderCopies.isEmpty else { return }

        olderCopies.forEach { $0.terminate() }
        for _ in 0..<30 where olderCopies.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        olderCopies.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    }
}
