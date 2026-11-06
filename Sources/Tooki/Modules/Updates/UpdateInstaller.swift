import Foundation
import Security

/// Downloads a release's DMG, checks it's signed like the running app, and swaps it in.
/// A small shell script waits for Tooki to quit, replaces the app and opens the new one.
enum UpdateInstaller {
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Returns once the new app is ready; quit Tooki then, and the script finishes the job.
    static func install(_ release: AppRelease) async throws {
        let currentApp = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: currentApp.deletingLastPathComponent().path) else {
            throw Failure("Can't replace Tooki in \(currentApp.deletingLastPathComponent().path)")
        }
        let work = FileManager.default.temporaryDirectory.appending(path: "TookiUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            try await prepare(release, replacing: currentApp, in: work)
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    private static func prepare(_ release: AppRelease, replacing currentApp: URL, in work: URL) async throws {
        let (download, _) = try await URLSession.shared.download(from: release.dmgURL)
        let dmg = work.appending(path: "Tooki.dmg")
        try FileManager.default.moveItem(at: download, to: dmg)

        let newApp = work.appending(path: currentApp.lastPathComponent)
        try await Task.detached { try copyApp(from: dmg, to: newApp, mountingAt: work.appending(path: "mount")) }.value
        guard isSignedLikeRunningApp(newApp) else {
            throw Failure("The download isn't signed like this copy of Tooki")
        }
        try startSwap(old: currentApp, new: newApp, work: work)
    }

    private static func copyApp(from dmg: URL, to destination: URL, mountingAt mount: URL) throws {
        try run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }
        try run("/usr/bin/ditto", mount.appending(path: destination.lastPathComponent).path, destination.path)
    }

    /// The new app must meet the running app's designated requirement: same bundle ID and certificate.
    private static func isSignedLikeRunningApp(_ app: URL) -> Bool {
        var running: SecCode?
        var runningStatic: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &runningStatic) == errSecSuccess, let runningStatic,
              SecCodeCopyDesignatedRequirement(runningStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let candidate
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess
    }

    /// Keeps the old app until the new one is in place, and puts it back if the move fails.
    private static func startSwap(old: URL, new: URL, work: URL) throws {
        let script = """
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            if mv "$2" "$4/Old.app"; then
                if mv "$3" "$2"; then rm -rf "$4/Old.app"; else mv "$4/Old.app" "$2"; fi
            fi
            xattr -dr com.apple.quarantine "$2" 2>/dev/null
            open "$2"
            rm -rf "$4"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "tooki-update", String(ProcessInfo.processInfo.processIdentifier), old.path, new.path, work.path]
        try process.run()
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure("Couldn't open the downloaded update")
        }
    }
}
