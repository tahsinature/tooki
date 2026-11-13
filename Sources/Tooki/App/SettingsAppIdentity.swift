import AppKit
import SwiftUI

/// One compact row for the app, installed version and any update that needs attention.
struct SettingsAppIdentity: View {
    let updater: Updater
    let openAbout: () -> Void
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: openAbout) {
            HStack(spacing: 7) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(BuildInfo.appName)
                    .font(SettingsTheme.font(11, weight: .medium))
                    .lineLimit(1)
                    .accessibilityLabel("About \(BuildInfo.appName)")
                Spacer(minLength: 0)
                Text("v\(BuildInfo.version)")
                    .font(SettingsTheme.metadataFont)
                    .monospacedDigit()
                    .foregroundStyle(SettingsTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(SettingsTheme.searchBackground, in: Capsule())
                    .fixedSize()
                    .accessibilityLabel("Version \(BuildInfo.version)")
                SettingsAppUpdateStatus(updater: updater)
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .foregroundStyle(SettingsTheme.primaryText)
            .background(isHovered ? SettingsTheme.sidebarSelection : SettingsTheme.secondaryBackground,
                        in: .rect(cornerRadius: SettingsTheme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: SettingsTheme.cardRadius).strokeBorder(SettingsTheme.cardBorder))
            .contentShape(.rect(cornerRadius: SettingsTheme.cardRadius))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(SettingsAppUpdateStatus.title(for: updater)). Open About for version details and update controls.")
        .accessibilityElement(children: .combine)
        .accessibilityValue(SettingsAppUpdateStatus.title(for: updater))
        .accessibilityHint("Opens version details and update controls")
    }
}
