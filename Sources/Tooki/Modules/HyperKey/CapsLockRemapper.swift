import Foundation

/// Uses the built-in `hidutil` tool to turn Caps Lock into F18, which Tooki then
/// treats as the Hyper key. No driver or system extension is needed.
/// The mapping lasts until it is cleared or the Mac restarts.
enum CapsLockRemapper {
    private static let capsLock = "0x700000039"
    private static let f18 = "0x70000006D"

    static func setEnabled(_ enabled: Bool) {
        let mapping = enabled
            ? #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\#(capsLock),"HIDKeyboardModifierMappingDst":\#(f18)}]}"#
            : #"{"UserKeyMapping":[]}"#
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", mapping]
        process.standardOutput = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
