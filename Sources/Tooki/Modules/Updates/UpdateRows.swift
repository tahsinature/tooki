import TookiDesignSystem
import SwiftUI

/// Tooki exposes checking preferences; Sparkle presents and installs updates.
struct UpdateRows: View {
    let updater: Updater

    var body: some View {
        if updater.isEnabled {
            SettingsRow(statusText) {
                HStack {
                    if let lastChecked = updater.lastChecked {
                        Text("Checked \(lastChecked, format: .relative(presentation: .named))")
                            .foregroundStyle(SettingsTheme.secondaryText)
                    }
                    Button("Check for Updates…", action: updater.check)
                        .disabled(!updater.canCheck)
                }
            }
            SettingsToggleRow("Check for updates automatically", isOn: Binding(
                get: { updater.checksAutomatically },
                set: { updater.setChecksAutomatically($0) }
            ))
        } else {
            SettingsRow("Updates") {
                Text("Off in dev builds").foregroundStyle(SettingsTheme.secondaryText)
            }
        }
    }

    private var statusText: String {
        switch updater.state {
        case .idle: "Updates"
        case .checking: "Checking for updates…"
        case .upToDate: "Tooki is up to date"
        case .available(let version): "Version \(version) is available"
        case .failed(let message): message
        }
    }
}
