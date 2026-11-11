import CoreGraphics

// Menu bar logic ported from Thaw (https://github.com/thaw-app/Thaw, GPLv3).
// See docs/THAW-REFERENCE.md for the upstream files.

/// The parts of the menu bar, left to right. Each divider hides the icons to its left.
public enum MenuBarSection: String, CaseIterable, Sendable {
    case alwaysHidden
    case hidden
    case shown

    /// The section of an icon centered at `midX`, given the left edges of the dividers.
    public static func of(midX: CGFloat, hiddenDividerX: CGFloat?, alwaysHiddenDividerX: CGFloat?) -> MenuBarSection {
        if let alwaysHiddenDividerX, midX < alwaysHiddenDividerX { return .alwaysHidden }
        if let hiddenDividerX, midX < hiddenDividerX { return .hidden }
        return .shown
    }
}

/// Which sections the dividers currently let through.
public enum MenuBarReveal: Sendable {
    case nothing
    case hidden
    case all

    /// Whether the divider of `section` must be stretched to push the icons left of it off screen.
    /// Showing the hidden section keeps the always-hidden one collapsed, like Thaw.
    public func collapses(_ section: MenuBarSection) -> Bool {
        switch (self, section) {
        case (_, .shown): false
        case (.nothing, _): true
        case (.hidden, .alwaysHidden): true
        default: false
        }
    }

    public func reveals(_ section: MenuBarSection) -> Bool {
        section == .shown || !collapses(section)
    }
}

/// On macOS 26 Control Center owns every icon's window, so the app an icon belongs to
/// is found by pairing its window with the Accessibility element at the same spot.
public enum MenuBarFrameMatcher {
    /// The index of the candidate whose center is within a point of `frame`'s center.
    public static func index(matching frame: CGRect, in candidates: [CGRect]) -> Int? {
        candidates.firstIndex { candidate in
            abs(candidate.midX - frame.midX) <= 1 && abs(candidate.midY - frame.midY) <= 1
        }
    }
}

/// Decides when hovering, clicking or scrolling on the menu bar reveals hidden icons.
public enum MenuBarTriggerZone {
    /// Whether `point` is on the menu bar but not on an app menu, the notch or an icon.
    /// All rectangles use the same coordinate space as `point`.
    public static func isEmptySpace(
        _ point: CGPoint,
        menuBar: CGRect,
        appMenuMaxX: CGFloat?,
        notch: CGRect?,
        itemFrames: [CGRect]
    ) -> Bool {
        guard menuBar.contains(point) else { return false }
        if let appMenuMaxX, point.x <= appMenuMaxX { return false }
        if let notch, notch.contains(point) { return false }
        return !itemFrames.contains { $0.contains(point) }
    }

    /// `true` to reveal, `false` to hide, or `nil` when the scroll was too small to count.
    public static func scrollReveals(deltaX: CGFloat, deltaY: CGFloat) -> Bool? {
        let average = (deltaX + deltaY) / 2
        if average > 5 { return true }
        if average < -5 { return false }
        return nil
    }
}

/// Where the Thaw Bar opens horizontally.
public enum ThawBarPlacement {
    static let margin: CGFloat = 8

    /// The bar's left edge, kept inside the screen.
    public static func x(
        for location: ThawBarLocation,
        width: CGFloat,
        screenMinX: CGFloat,
        screenMaxX: CGFloat,
        mouseX: CGFloat,
        dividerX: CGFloat?
    ) -> CGFloat {
        let preferred = switch location {
        case .underMouse: mouseX - width / 2
        case .underDivider: (dividerX ?? mouseX) - width / 2
        case .rightAligned: screenMaxX - width
        }
        let lowest = screenMinX + margin
        let highest = screenMaxX - margin - width
        return max(lowest, min(preferred, highest))
    }
}
