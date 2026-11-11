import AppKit

// Private Window Server calls, ported from Thaw 2 (Shared/Bridging/Shims.swift and
// Bridging.swift, https://github.com/thaw-app/Thaw, GPLv3). Every wrapper returns nil or []
// when a call fails, so callers can fall back to Accessibility.

private typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ key: CFString,
    _ value: CFTypeRef
) -> CGError

@_silgen_name("CGSGetWindowCount")
private func CGSGetWindowCount(_ cid: CGSConnectionID, _ targetCID: CGSConnectionID, _ count: inout Int32) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
private func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
private func CGSGetScreenRectForWindow(_ cid: CGSConnectionID, _ windowID: CGWindowID, _ rect: inout CGRect) -> CGError

@_silgen_name("CGSGetWindowLevel")
private func CGSGetWindowLevel(_ cid: CGSConnectionID, _ windowID: CGWindowID, _ level: inout CGWindowLevel) -> CGError

enum WindowServer {
    /// A status item's window. Frames use global coordinates with a top-left origin.
    struct Window: Sendable {
        let id: CGWindowID
        let frame: CGRect
        /// The app that draws the window. On macOS 26 that is Control Center for every icon.
        let ownerPID: pid_t
    }

    /// The windows of every app's menu bar icons, hidden ones included.
    static func menuBarItemWindows() -> [Window] {
        let connection = CGSMainConnectionID()
        var count: Int32 = 0
        guard CGSGetWindowCount(connection, 0, &count) == .success, count > 0 else { return [] }
        var ids = [CGWindowID](repeating: 0, count: Int(count))
        var written: Int32 = 0
        guard CGSGetProcessMenuBarWindowList(connection, 0, count, &ids, &written) == .success else { return [] }

        let menuBarLevel = CGWindowLevelForKey(.mainMenuWindow)
        let itemIDs = ids.prefix(Int(written)).filter { id in
            var level: CGWindowLevel = 0
            // The list also holds the menu bar's own window.
            return id != 0 && CGSGetWindowLevel(connection, id, &level) == .success && level != menuBarLevel
        }
        return windows(itemIDs)
    }

    /// The window's current frame, read fresh from the Window Server.
    static func frame(of windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        guard CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect) == .success else { return nil }
        return rect
    }

    /// Lets a background app hide the pointer, which it otherwise can't.
    static func allowCursorChangesInBackground() {
        let connection = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }

    /// Window owners and frames are readable without the Screen Recording permission.
    private static func windows(_ ids: [CGWindowID]) -> [Window] {
        guard let array = windowArray(ids),
              let descriptions = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]]
        else { return [] }
        return descriptions.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return Window(id: id, frame: frame, ownerPID: pid)
        }
    }

    /// The Window Server takes window IDs as a CFArray of raw values, not of CFNumbers.
    static func windowArray(_ ids: [CGWindowID]) -> CFArray? {
        var values = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        return CFArrayCreate(kCFAllocatorDefault, &values, values.count, nil)
    }
}
