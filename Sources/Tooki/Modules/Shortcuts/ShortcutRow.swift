import SwiftUI
import TookiKit

/// One action with its hotkey and an enable checkbox, laid out like Raycast's extension list.
struct ShortcutRow: View {
    @Binding var shortcut: Shortcut
    let validate: (KeyCombo) -> String?
    var warning: String?
    let onRecordingChange: (Bool) -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        let info = ShortcutActionInfo(action: shortcut.action)
        HStack(spacing: 12) {
            ShortcutActionIcon(icon: info.icon)
            Text(info.title)
                .font(SettingsTheme.rowTitleFont)
            Spacer()
            if let warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(warning)
            }
            HotkeyRecorder(combo: KeyCombo(shortcut.keys), validate: validate, onRecordingChange: onRecordingChange) {
                shortcut.keys = $0?.description ?? ""
            }
            .frame(width: 140, alignment: .leading)
            Toggle("Enabled", isOn: $shortcut.enabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
            removeButton
        }
        .opacity(shortcut.enabled ? 1 : 0.5)
    }

    // Built-in rows keep the space empty so the checkboxes line up across sections.
    @ViewBuilder
    private var removeButton: some View {
        if let onRemove {
            Button("Remove", systemImage: "minus.circle", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        } else {
            Color.clear.frame(width: 16, height: 16)
        }
    }
}
