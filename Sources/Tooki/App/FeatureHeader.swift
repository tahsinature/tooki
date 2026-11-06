import SwiftUI

struct FeatureHeader: View {
    let page: SettingsPage

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 32) {
                artwork(size: 160)
                heading
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 600, idealWidth: 600)
            .padding(28)

            compactHeader
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.heroGradient, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(SettingsTheme.accent.opacity(0.18)))
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                artwork(size: 48)
                Text(page.title)
                    .font(.title2.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(page.summary)
                .font(.callout)
                .foregroundStyle(SettingsTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if page == .hyperKey {
                KeyCaps(symbols: ["⌃", "⌥", "⇧", "⌘"])
                    .accessibilityLabel("Control, Option, Shift, and Command")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(page == .hyperKey ? "YOUR KEYBOARD, WITH SUPERPOWERS" : "YOUR MAC TOOLKIT")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(SettingsTheme.secondaryText)
            Text(page.title)
                .font(.system(size: 34, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(page.summary)
                .font(.callout)
                .foregroundStyle(SettingsTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if page == .hyperKey {
                KeyCaps(symbols: ["⌃", "⌥", "⇧", "⌘"], size: .large)
                    .accessibilityLabel("Control, Option, Shift, and Command")
            }
        }
    }

    @ViewBuilder
    private func artwork(size: CGFloat) -> some View {
        if page == .hyperKey {
            HyperKeyArtwork(size: size)
        } else {
            IconTile(symbol: page.icon, color: SettingsTheme.accent, size: size * 0.72)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-6))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 12)
        }
    }
}
