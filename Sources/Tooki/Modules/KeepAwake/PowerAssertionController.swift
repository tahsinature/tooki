import Foundation
import IOKit.pwr_mgt
import TookiKit

/// Serial native resource ownership. Cancelled or shutdown requests cannot acquire an assertion.
@MainActor
final class PowerAssertionController {
    private var id: IOPMAssertionID = 0
    private var heldMode: KeepAwakeMode?
    private var isShutdown = false

    func set(_ mode: KeepAwakeMode?) -> Bool {
        guard !isShutdown, !Task.isCancelled else { return false }
        guard heldMode != mode else { return heldMode != nil }
        release()
        guard let mode else { return false }
        let type = mode == .display ? "PreventUserIdleDisplaySleep" : "PreventUserIdleSystemSleep"
        if IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                     "Tooki Keep Awake" as CFString, &id) == kIOReturnSuccess {
            heldMode = mode
        }
        return heldMode != nil
    }

    func shutdown() {
        isShutdown = true
        release()
    }

    private func release() {
        if heldMode != nil { IOPMAssertionRelease(id) }
        heldMode = nil
    }
}
