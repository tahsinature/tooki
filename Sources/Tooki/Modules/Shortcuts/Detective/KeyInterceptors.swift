import AppKit
import CoreGraphics

/// Programs running an event tap that can change or block key presses (skhd, Karabiner, Tooki…).
enum KeyInterceptors {
    static func running() -> [String] {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return [] }
        var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &taps, &count) == .success else { return [] }

        let keyDown = CGEventMask(1) << CGEventType.keyDown.rawValue
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let names = taps
            .filter { $0.enabled && $0.options != .listenOnly && $0.eventsOfInterest & keyDown != 0 && $0.tappingProcess != ownPID }
            .map { NSRunningApplication(processIdentifier: $0.tappingProcess)?.localizedName ?? "Process \($0.tappingProcess)" }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}
