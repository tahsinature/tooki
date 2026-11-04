import AppKit
import SwiftUI
import TookiKit

struct KeepAwakeView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let keepAwake: KeepAwake

    private let durations = [(15, "15 min"), (60, "1 hour"), (120, "2 hours"), (0, "Until off")]

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.largeTitle)
                        .foregroundStyle(keepAwake.isActive ? Color.accentColor : .secondary)
                    VStack(alignment: .leading) {
                        Text(keepAwake.isActive ? "Keeping your Mac awake" : "Your Mac can sleep normally")
                            .font(.headline)
                        Text(keepAwake.statusText).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if keepAwake.manualUntil != nil {
                        Button("Turn Off") { keepAwake.stop() }
                    }
                }
                HStack {
                    ForEach(durations, id: \.0) { minutes, label in
                        Button(label) { keepAwake.start(minutes: minutes) }
                    }
                }
            } footer: {
                Text("Shortcut: Hyper + A. With the lid closed, macOS still sleeps unless an external display is connected.")
                    .foregroundStyle(.secondary)
            }

            Section("Settings") {
                Picker("Keep awake", selection: $config.value.keepAwake.mode) {
                    Text("Mac and display").tag(KeepAwakeMode.display)
                    Text("Mac only (display can sleep and lock)").tag(KeepAwakeMode.system)
                }
                Picker("Shortcut turns on for", selection: $config.value.keepAwake.defaultDurationMinutes) {
                    ForEach(durations, id: \.0) { minutes, label in
                        Text(label).tag(minutes)
                    }
                }
                Toggle("Only while plugged in", isOn: $config.value.keepAwake.onlyOnPower)
            }

            Section {
                StringListEditor(items: $config.value.keepAwake.activateForApps, placeholder: "com.apple.Terminal")
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            if let id = app.bundleIdentifier, !config.value.keepAwake.activateForApps.contains(id) {
                                config.value.keepAwake.activateForApps.append(id)
                            }
                        }
                    }
                }
            } header: {
                Text("Stay awake while these apps are running")
            }
        }
        .formStyle(.grouped)
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
