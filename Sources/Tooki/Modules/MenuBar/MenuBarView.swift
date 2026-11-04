import SwiftUI
import TookiKit

struct MenuBarView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let organizer: MenuBarOrganizer

    private let autoHideOptions = [0, 5, 10, 30, 60]

    var body: some View {
        Form {
            Section {
                Toggle("Organize menu bar icons", isOn: $config.value.menuBar.enabled)
                Toggle("Hide icons when Tooki starts", isOn: $config.value.menuBar.startCollapsed)
                Picker("Hide again after", selection: $config.value.menuBar.autoHideSeconds) {
                    ForEach(autoHideOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? "Never" : "\(seconds) seconds").tag(seconds)
                    }
                }
            }

            Section {
                LabeledContent("Hidden icons") {
                    Button(organizer.isCollapsed ? "Show" : "Hide") { organizer.toggle() }
                        .disabled(!organizer.isInstalled)
                }
            } footer: {
                Text("Shortcut: Hyper + M")
                    .foregroundStyle(.secondary)
            }

            Section("How to choose which icons hide") {
                Label("Hold ⌘ and drag an icon to the left of the │ separator to hide it.", systemImage: "1.circle")
                Label("Drag it back to the right of the separator to keep it visible.", systemImage: "2.circle")
                Label("Click the arrow (› or ‹) to show or hide them.", systemImage: "3.circle")
                Text("macOS remembers icon positions itself, so the arrangement is not part of config.json.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
