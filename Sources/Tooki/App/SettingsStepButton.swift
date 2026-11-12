import SwiftUI

/// A compact step button with press-and-hold repetition and a full hit area.
struct SettingsStepButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .font(.system(size: 8, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.35))
        .background(isHovered && isEnabled ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
        .help(title)
    }
}
