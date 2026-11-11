import AppKit

extension NSScreen {
    /// Taller on Macs with a notch. The standard thickness while the menu bar auto-hides.
    var menuBarHeight: CGFloat {
        let height = frame.maxY - visibleFrame.maxY
        return height > 0 ? height : NSStatusBar.system.thickness
    }

    /// The menu bar in global coordinates with a top-left origin, like Window Server frames.
    var menuBarFrame: CGRect {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? frame.maxY
        return CGRect(x: frame.minX, y: primaryMaxY - frame.maxY, width: frame.width, height: menuBarHeight)
    }

    /// The notch's horizontal extent in screen coordinates, on Macs that have one.
    var notchRange: ClosedRange<CGFloat>? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea, left.maxX < right.minX else { return nil }
        return (frame.minX + left.maxX)...(frame.minX + right.minX)
    }

    /// The notch in the same coordinates as `menuBarFrame`.
    var notchFrame: CGRect? {
        notchRange.map { CGRect(x: $0.lowerBound, y: menuBarFrame.minY, width: $0.upperBound - $0.lowerBound, height: menuBarHeight) }
    }
}
