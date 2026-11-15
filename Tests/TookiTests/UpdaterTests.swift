import Foundation
import Sparkle
import Testing
@testable import Tooki

@MainActor
struct UpdaterTests {
    @Test func developmentBuildCannotStartOrCheckForUpdates() {
        let updater = Updater(isRelease: false)
        updater.start(initialAutomaticChecks: true)
        updater.setChecksAutomatically(true)
        updater.check()
        #expect(!updater.isEnabled)
        #expect(!updater.canCheck)
        #expect(!updater.checksAutomatically)
        #expect(updater.lastChecked == nil)
        #expect(updater.state == .idle)
    }

    @Test func updateCycleDistinguishesNoUpdateCancellationAndFailure() {
        #expect(Updater.stateAfterCycle(error: nil) == .idle)
        #expect(Updater.stateAfterCycle(error: NSError(domain: SUSparkleErrorDomain,
                    code: Int(SUError.noUpdateError.rawValue))) == .upToDate)
        #expect(Updater.stateAfterCycle(error: NSError(domain: SUSparkleErrorDomain,
                    code: Int(SUError.installationCanceledError.rawValue))) == .idle)
        let failure = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.signatureError.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Invalid update signature"])
        #expect(Updater.stateAfterCycle(error: failure) == .failed("Invalid update signature"))
        let unrelated = NSError(domain: "Other", code: Int(SUError.noUpdateError.rawValue),
                                userInfo: [NSLocalizedDescriptionKey: "Network error"])
        #expect(Updater.stateAfterCycle(error: unrelated) == .failed("Network error"))
    }
}
