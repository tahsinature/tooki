import AppKit

/// Clicks and moves menu bar icons with mouse events aimed at the icon's window, like Thaw.
/// Ported from Thaw 2 (MenuBarItemEventTypes.swift, MenuBarItemManager+Click.swift and
/// +MoveEvents.swift, https://github.com/thaw-app/Thaw, GPLv3).
/// The pointer is hidden while the events play and then put back, so it never visibly jumps.
@MainActor
enum MenuBarItemEvents {
    enum Side {
        case left
        case right
    }

    /// A window to aim events at, and the process that handles them.
    struct Target {
        let windowID: CGWindowID
        let pid: pid_t
    }

    // MARK: Clicking

    static func click(_ target: Target) async -> Bool {
        guard let frame = WindowServer.frame(of: target.windowID), isOnDisplay(frame.center),
              await waitForIdleInput()
        else { return false }
        return await withHiddenCursor(at: frame.center) {
            guard let down = mouseEvent(.leftMouseDown, at: frame.center, aimedAt: target),
                  let up = mouseEvent(.leftMouseUp, at: frame.center, aimedAt: target)
            else { return false }
            let pressed = await MenuBarEventRelay.post(down, to: target.pid, delivery: .barrier)
            return await release(up, to: target.pid, delivery: .barrier) && pressed
        }
    }

    // MARK: Moving

    /// ⌘-drags the icon next to `anchor`: the press is aimed at the icon's window and the
    /// release at the anchor's, so nothing has to travel across the menu bar.
    static func move(_ item: Target, to side: Side, of anchor: Target, anchorIsDivider: Bool) async -> Bool {
        guard let start = WindowServer.frame(of: item.windowID),
              let anchorFrame = WindowServer.frame(of: anchor.windowID),
              await waitForIdleInput()
        else { return false }
        let drop = dropPoint(side, of: anchorFrame, anchorIsDivider: anchorIsDivider)
        return await withHiddenCursor(at: drop) {
            guard let down = mouseEvent(.leftMouseDown, at: pressPoint(near: drop), aimedAt: item, isMove: true),
                  await MenuBarEventRelay.post(down, to: item.pid, delivery: .scromble),
                  let lifted = await originChange(of: item.windowID, from: start.origin)
            else {
                await releaseInPlace(item, at: drop)
                return false
            }
            // Lifting the icon shifts its neighbours, so the drop point is measured again.
            let liveFrame = WindowServer.frame(of: anchor.windowID) ?? anchorFrame
            let liveDrop = dropPoint(side, of: liveFrame, anchorIsDivider: anchorIsDivider)
            guard let up = mouseEvent(.leftMouseUp, at: liveDrop, aimedAt: anchor, isMove: true),
                  await release(up, to: item.pid, delivery: .scromble)
            else {
                await releaseInPlace(item, at: drop)
                return false
            }
            return await originChange(of: item.windowID, from: lifted) != nil
        }
    }

    /// Just past the anchor's edge. Dropping on a divider's own edge lets macOS pick either side,
    /// so the point moves one more point into the requested side.
    private static func dropPoint(_ side: Side, of anchor: CGRect, anchorIsDivider: Bool) -> CGPoint {
        let bias: CGFloat = anchorIsDivider ? 1 : 0
        let y = anchor.minY
        return switch side {
        case .left: CGPoint(x: anchor.minX - bias, y: y)
        case .right: CGPoint(x: anchor.maxX + bias, y: y)
        }
    }

    /// Before macOS 26 a press at the drop point hits whatever sits there, so it goes off screen.
    private static func pressPoint(near drop: CGPoint) -> CGPoint {
        if #available(macOS 26, *) { return drop }
        let covered = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        return CGPoint(x: max(20_000, covered.maxX + 1000), y: max(20_000, covered.maxY + 1000))
    }

    /// Waits up to half a second for the icon's window to move.
    private static func originChange(of windowID: CGWindowID, from origin: CGPoint) async -> CGPoint? {
        for _ in 0..<50 {
            if let current = WindowServer.frame(of: windowID)?.origin, current != origin { return current }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }

    // MARK: Events

    /// A release is sent twice: Thaw found a single one can leave the icon stuck mid-drag.
    private static func release(_ up: CGEvent, to pid: pid_t, delivery: MenuBarEventRelay.Delivery) async -> Bool {
        let first = await MenuBarEventRelay.post(up, to: pid, delivery: delivery)
        let second = await MenuBarEventRelay.post(up, to: pid, delivery: delivery)
        return first || second
    }

    /// Ends a drag that failed halfway, so the icon isn't left floating.
    private static func releaseInPlace(_ item: Target, at point: CGPoint) async {
        guard let up = mouseEvent(.leftMouseUp, at: point, aimedAt: item, isMove: true) else { return }
        _ = await release(up, to: item.pid, delivery: .scromble)
    }

    private static func mouseEvent(_ type: CGEventType, at point: CGPoint, aimedAt target: Target, isMove: Bool = false) -> CGEvent? {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
            return nil
        }
        let windowID = Int64(target.windowID)
        event.flags = isMove ? .maskCommand : []
        event.setIntegerValueField(.eventSourceUserData, value: nextUserData())
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowID)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowID)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(target.pid))
        if isMove {
            // An undocumented window field that makes moves more reliable (Thaw).
            event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: windowID)
        } else {
            event.setIntegerValueField(.mouseEventClickState, value: type == .leftMouseDown ? 1 : 0)
        }
        return event
    }

    /// An event that does nothing, used by the relay to mark the start and end of a delivery.
    static func nullEvent() -> CGEvent? {
        let event = CGEvent(source: nil)
        event?.setIntegerValueField(.eventSourceUserData, value: nextUserData())
        return event
    }

    /// Tags each event so the relay's taps can recognize it.
    private static var lastUserData = Int64.random(in: 1...(1 << 40))

    private static func nextUserData() -> Int64 {
        lastUserData += 1
        return lastUserData
    }

    // MARK: Pointer

    /// Waits up to a second for the user to let go of the mouse and modifier keys,
    /// so synthetic events don't mix with real ones.
    private static func waitForIdleInput() async -> Bool {
        for _ in 0..<20 {
            let idle = NSEvent.pressedMouseButtons == 0
                && NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
                && CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved) > 0.05
            if idle { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    /// Hides the pointer, parks it at `point` while `body` runs, then puts it back.
    private static func withHiddenCursor<T>(at point: CGPoint, _ body: () async -> T) async -> T {
        let saved = CGEvent(source: nil)?.location
        permitLocalEvents()
        WindowServer.allowCursorChangesInBackground()
        CGDisplayHideCursor(CGMainDisplayID())
        if isOnDisplay(point) { CGWarpMouseCursorPosition(point) }
        defer {
            if let saved { CGWarpMouseCursorPosition(saved) }
            CGDisplayShowCursor(CGMainDisplayID())
        }
        try? await Task.sleep(for: .milliseconds(10))
        return await body()
    }

    /// Stops macOS from ignoring real mouse input for a moment after each synthetic event.
    private static func permitLocalEvents() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let everything: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source?.setLocalEventsFilterDuringSuppressionState(everything, state: .eventSuppressionStateRemoteMouseDrag)
        source?.setLocalEventsFilterDuringSuppressionState(everything, state: .eventSuppressionStateSuppressionInterval)
        source?.localEventsSuppressionInterval = 0
    }

    private static func isOnDisplay(_ point: CGPoint) -> Bool {
        var count: UInt32 = 0
        return CGGetDisplaysWithPoint(point, 0, nil, &count) == .success && count > 0
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
