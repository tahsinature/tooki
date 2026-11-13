import AppKit
import SwiftUI

/// The sidebar's app identity, installed version and entry point to About and updates.
struct SettingsAppIdentity: View {
    let updater: Updater
    let openAbout: () -> Void
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: openAbout) {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 39, height: 39)
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 15)

                HStack(spacing: 7) {
                    Text(BuildInfo.appName)
                        .font(.system(size: 14, weight: .medium))
                        .accessibilityLabel("About \(BuildInfo.appName)")
                    Text("v\(BuildInfo.version)")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(SettingsTheme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.035), in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5) }
                        .accessibilityLabel("Version \(BuildInfo.version)")
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 15)

                SettingsAppUpdateStatus(updater: updater)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(SettingsTheme.primaryText)
            .background(Color.primary.opacity(isHovered ? 0.055 : 0.025))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.10 : 0.06), lineWidth: 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("View version details and update controls in About")
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens version details and update controls")
    }
}
