import SwiftUI

/// Shared pointer, press and keyboard feedback. Padding belongs inside the hit target.
struct InteractionButtonStyle: ButtonStyle {
    var restingFill: Color = .clear
    var radius: CGFloat = 6
    var horizontalPadding: CGFloat = 0
    var verticalPadding: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        InteractionButtonBody(
            configuration: configuration, style: self
        )
    }
}

private struct InteractionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let style: InteractionButtonStyle
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var isHovered = false

    var body: some View {
        configuration.label
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.primary)
            .opacity(isEnabled ? 1 : 0.45)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.restingFill, in: .rect(cornerRadius: style.radius))
            .background {
                RoundedRectangle(cornerRadius: style.radius)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07))
                    .opacity(isEnabled && (isHovered || configuration.isPressed) ? 1 : 0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: style.radius)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .opacity(isEnabled && isFocused ? 1 : 0)
            }
            .contentShape(.rect(cornerRadius: style.radius))
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    }
}
