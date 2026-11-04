import Foundation
import IOKit
import IOKit.hidsystem

/// Turns Caps Lock on or off directly, since the physical key is remapped to F18.
enum CapsLockState {
    /// The IOKit call can take a few hundred milliseconds, so it runs off the
    /// main thread to keep the keyboard event tap responsive.
    static func toggle() {
        DispatchQueue.global(qos: .userInteractive).async { toggleNow() }
    }

    private static func toggleNow() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connection) }

        var isOn = false
        IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &isOn)
        IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), !isOn)
    }
}
