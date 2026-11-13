import SwiftUI

/// A compact summary of the shared updater. Checking and installation stay in About.
struct SettingsAppUpdateStatus: View {
    let updater: Updater

    var body: some View {
        HStack(spacing: 6) {
            if updater.isEnabled && (updater.state == .checking || isInstalling) {
                ProgressView().controlSize(.mini).frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 10))
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .medium))
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(updater.shouldPrompt ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.025))
    }

    private var tint: Color {
        updater.shouldPrompt ? .accentColor : SettingsTheme.secondaryText
    }

    private var isInstalling: Bool {
        if case .installing = updater.state { return true }
        return false
    }

    private var title: String {
        guard updater.isEnabled else { return "Development build" }
        switch updater.state {
        case .idle: return "Check for updates"
        case .checking: return "Checking…"
        case .upToDate: return "Up to date"
        case .available(let release):
            return updater.shouldPrompt ? "\(release.version) available" : "Update skipped"
        case .installing: return "Installing update…"
        case .failed: return "Couldn't check"
        }
    }

    private var symbol: String {
        guard updater.isEnabled else { return "hammer" }
        switch updater.state {
        case .upToDate: return "checkmark.circle"
        case .available: return updater.shouldPrompt ? "arrow.up.circle" : "minus.circle"
        case .failed: return "exclamationmark.circle"
        default: return "arrow.triangle.2.circlepath"
        }
    }
}
