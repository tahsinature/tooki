import AppKit
import ServiceManagement
import SwiftUI

struct GeneralView: View {
    let app: AppController
    @ViewState private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            PageHeader(page: .general)

            Section("Permissions") {
                LabeledContent {
                    if app.hasAccessibility {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") {
                            Accessibility.requestAccess()
                            Accessibility.openSystemSettings()
                        }
                    }
                } label: {
                    Text("Accessibility")
                    Text("Needed for the Hyper key, snippet keywords and pasting.")
                }
            }

            Section("Startup") {
                Toggle("Open Tooki at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section {
                LabeledContent("Folder") {
                    Text(StoragePaths.configDirectory.path(percentEncoded: false))
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.config.fileURL])
                    }
                    Button("Reload Now") { app.reloadFromDisk() }
                }
                ForEach(app.loadErrors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Configuration")
            } footer: {
                Text("config.json and snippets.json can live in your dotfiles. Symlink the folder or set TOOKI_CONFIG_DIR. Edits made outside Tooki are picked up automatically.")
                    .foregroundStyle(.secondary)
            }

            URLSchemeSection()
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
