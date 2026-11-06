import SwiftUI

/// Layered shapes keep the feature artwork crisp at every window size.
struct HyperKeyArtwork: View {
    var size: CGFloat = 160

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color(red: 0.29, green: 0.16, blue: 0.47))
                .overlay(RoundedRectangle(cornerRadius: size * 0.2).stroke(.white.opacity(0.25)))
                .padding(.top, size * 0.12)
            VStack(spacing: size * 0.12) {
                Image(systemName: "bolt")
                    .font(.system(size: size * 0.32, weight: .medium))
                Text("⌃ ⌥ ⇧ ⌘")
                    .font(.system(size: size * 0.12, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size * 0.8)
            .background(
                LinearGradient(colors: [Color(red: 0.94, green: 0.77, blue: 1), SettingsTheme.accent],
                               startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: size * 0.2)
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.2).stroke(.white.opacity(0.6)))
        }
        .frame(width: size, height: size * 0.94)
        .shadow(color: .black.opacity(0.3), radius: 16, y: 14)
        .accessibilityHidden(true)
    }
}
