import AppKit
import SwiftUI
import TookiKit
import UniformTypeIdentifiers

struct ShortcutsView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let detective: ShortcutDetective
    let onRecordingChange: (Bool) -> Void

    /// macOS and skhd shortcuts, to warn about clashes.
    @ViewState private var otherShortcuts = ShortcutCatalog(entries: [])

    private var appActions: [String] {
        var seen = Set<String>()
        return config.value.shortcuts.map(\.action).filter { $0.hasPrefix("open:") && seen.insert($0).inserted }
    }

    var body: some View {
        Form {
            PageHeader(page: .shortcuts)

            ShortcutDetectiveSection(detective: detective, tookiShortcuts: config.value.shortcuts)

            Section {
                ForEach(HotkeyAction.builtIns, id: \.self) { action in
                    row(for: action)
                }
            } header: {
                Text("Tooki")
            } footer: {
                Text("Click a hotkey to record a new one. Right-click to remove it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(appActions, id: \.self) { action in
                    row(for: action) { removeShortcuts(for: action) }
                }
                Button("Add App Shortcut…", systemImage: "plus", action: addApps)
            } header: {
                Text("Apps")
            } footer: {
                Text("Open an app, or switch to it if it's already running.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { otherShortcuts = .load() }
    }

    private func row(for action: String, onRemove: (() -> Void)? = nil) -> some View {
        ShortcutRow(
            shortcut: binding(for: action),
            validate: { problem(with: $0, for: action) },
            warning: warning(for: action),
            onRecordingChange: { isRecording in
                // The detective would otherwise see (or block) the keys being recorded.
                if isRecording { detective.stop() }
                onRecordingChange(isRecording)
            },
            onRemove: onRemove
        )
    }

    /// The first shortcut for an action. Built-in actions without one get it created on first edit.
    private func binding(for action: String) -> Binding<Shortcut> {
        Binding {
            config.value.shortcuts.first { $0.action == action } ?? Shortcut(action: action)
        } set: { newValue in
            if let index = config.value.shortcuts.firstIndex(where: { $0.action == action }) {
                config.value.shortcuts[index] = newValue
            } else {
                config.value.shortcuts.append(newValue)
            }
        }
    }

    private func problem(with combo: KeyCombo, for action: String) -> String? {
        if combo.isReservedBySystem {
            return "\(combo.symbols.joined()) is a standard macOS shortcut"
        }
        let other = config.value.shortcuts.first { $0.action != action && KeyCombo($0.keys) == combo }
        return other.map { "Already used by \(ShortcutActionInfo(action: $0.action).title)" }
    }

    /// Recording is still allowed: the user may mean to take the shortcut over.
    private func warning(for action: String) -> String? {
        guard let combo = KeyCombo(binding(for: action).wrappedValue.keys),
              let clash = otherShortcuts.matches(combo).first
        else { return nil }
        return "Also used by \(clash.owner): \(clash.detail)"
    }

    private func removeShortcuts(for action: String) {
        config.value.shortcuts.removeAll { $0.action == action }
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let action = "open:" + (Bundle(url: url)?.bundleIdentifier ?? url.path)
            if !config.value.shortcuts.contains(where: { $0.action == action }) {
                config.value.shortcuts.append(Shortcut(action: action))
            }
        }
    }
}
