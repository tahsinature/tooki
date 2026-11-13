import AppKit
import SwiftUI
import TookiKit

struct KeepAwakeView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let keepAwake: KeepAwake

    private let durations = [(15, "15 min"), (60, "1 hour"), (120, "2 hours"), (0, "Until off")]

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Status") {
                SettingsCardRow { status }
                SettingsCardRow {
                    HStack {
                        ForEach(durations, id: \.0) { minutes, label in
                            Button(label) { keepAwake.start(minutes: minutes) }
                        }
                    }
                }
            } footer: {
                Text("Shortcut: Hyper + A. With the lid closed, macOS still sleeps unless an external display is connected.")
            }

            SettingsSection("Settings") {
                SettingsRow("Keep awake") {
                    Picker("Keep awake", selection: $config.value.keepAwake.mode) {
                        Text("Mac and display").tag(KeepAwakeMode.display)
                        Text("Mac only (display can sleep and lock)").tag(KeepAwakeMode.system)
                    }
                    .settingsMenuPicker()
                }
                SettingsRow("Shortcut turns on for") {
                    Picker("Shortcut turns on for", selection: $config.value.keepAwake.defaultDurationMinutes) {
                        ForEach(durations, id: \.0) { minutes, label in
                            Text(label).tag(minutes)
                        }
                    }
                    .settingsMenuPicker()
                }
                SettingsToggleRow("Show coffee icon in the menu bar while awake", isOn: $config.value.keepAwake.showMenuBarIcon)
                SettingsToggleRow("Only while plugged in", isOn: $config.value.keepAwake.onlyOnPower)
            }

            SettingsSection("Stay awake while these apps are running") {
                StringListEditor(items: $config.value.keepAwake.activateForApps, placeholder: "com.apple.Terminal")
                SettingsCardRow {
                    Menu("Add Running App") {
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                                if let id = app.bundleIdentifier, !config.value.keepAwake.activateForApps.contains(id) {
                                    config.value.keepAwake.activateForApps.append(id)
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
            }
        }
    }

    private var status: some View {
        HStack(spacing: 14) {
            Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.largeTitle)
                .foregroundStyle(keepAwake.isActive ? Color.accentColor : .secondary)
            SettingsRowLabel(
                title: keepAwake.isActive ? "Keeping your Mac awake" : "Your Mac can sleep normally",
                description: keepAwake.statusText
            )
            if keepAwake.manualUntil != nil {
                Button("Turn Off") { keepAwake.stop() }
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
