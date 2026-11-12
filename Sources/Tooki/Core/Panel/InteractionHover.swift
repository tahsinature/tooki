import SwiftUI

/// Hover for native controls that already provide their own press and focus behavior.
struct InteractionHover: ViewModifier {
    var radius: CGFloat = 6
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.primary.opacity(0.07))
                    .opacity(isHovered && isEnabled ? 1 : 0)
            }
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    }
}
