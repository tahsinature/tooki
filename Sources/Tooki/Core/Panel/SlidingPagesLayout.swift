import SwiftUI

/// Reused by shelf details and converters. Keeps the width fixed and interpolates height
/// as the current page slides into place. Clamp spring overshoot before indexing pages.
struct SlidingPagesLayout: Layout {
    var page: CGFloat
    let width: CGFloat

    var animatableData: CGFloat {
        get { page }
        set { page = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return CGSize(width: width, height: 0) }
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let position = min(max(page, 0), CGFloat(heights.count - 1))
        let lower = Int(position)
        let upper = min(lower + 1, heights.count - 1)
        let height = heights[lower] + (heights[upper] - heights[lower]) * (position - CGFloat(lower))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + (CGFloat(index) - page) * width, y: bounds.minY),
                          proposal: ProposedViewSize(width: width, height: nil))
        }
    }
}
