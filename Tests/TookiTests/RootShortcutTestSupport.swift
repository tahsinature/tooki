import Foundation

/// Await the queued navigation callback rather than relying on a fixed sleep.
@MainActor
func awaitRootShortcut(_ dispatch: (_ completed: @escaping () -> Void) -> Bool) async -> Bool {
    await withCheckedContinuation { continuation in
        let handled = dispatch { continuation.resume(returning: true) }
        if !handled { continuation.resume(returning: false) }
    }
}
