import TookiDesignSystem
import SwiftUI

/// The version stays visible; an extra indicator appears for update activity or attention.
struct SettingsAppUpdateStatus: View {
    let updater: Updater

    var body: some View {
        Group {
            if updater.isEnabled {
                if updater.state == .checking {
                    ProgressView().controlSize(.mini).frame(width: 12, height: 12)
                } else if updater.shouldPrompt {
                    Image(systemName: "arrow.up.circle")
                        .foregroundStyle(Color.accentColor)
                } else if case .failed = updater.state {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(SettingsTheme.secondaryText)
                }
            }
        }
        .font(.system(size: 11))
        .help(Self.title(for: updater))
        .accessibilityHidden(true)
    }

    static func title(for updater: Updater) -> String {
        guard updater.isEnabled else { return "Development build" }
        switch updater.state {
        case .idle: return "Check for updates"
        case .checking: return "Checking…"
        case .upToDate: return "Up to date"
        case .available(let version): return "\(version) available"
        case .failed: return "Couldn't check"
        }
    }
}
