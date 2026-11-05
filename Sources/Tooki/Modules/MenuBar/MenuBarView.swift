import SwiftUI
import TookiKit

struct MenuBarView: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let organizer: MenuBarOrganizer
    let arranger: MenuBarArranger

    private let autoHideOptions = [0, 5, 10, 30, 60]

    var body: some View {
        Form {
            PageHeader(page: .menuBar)

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

            MenuBarLayoutEditor(config: config, organizer: organizer, arranger: arranger)

            Section("Arranging by hand") {
                Label("Hold ⌘ and drag an icon left of the │ separator to hide it, or right of it to show it.", systemImage: "hand.draw")
                Label("Click “Reload from Menu Bar”, then “Apply & Save” to keep that arrangement in config.json.", systemImage: "square.and.arrow.down")
            }
        }
        .formStyle(.grouped)
    }
}
