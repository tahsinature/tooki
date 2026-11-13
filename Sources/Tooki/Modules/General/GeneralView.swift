import AppKit
import ServiceManagement
import SwiftUI

struct GeneralView: View {
    let app: AppController
    @ViewState private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        SettingsScrollPage {
            SettingsSection("Permissions") {
                SettingsRow("Accessibility", description: "Needed for the Hyper key, snippet keywords and pasting.") {
                    if app.hasAccessibility {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") {
                            Accessibility.requestAccess()
                            Accessibility.openSystemSettings()
                        }
                    }
                }
            }

            SettingsSection("Startup") {
                SettingsToggleRow("Open Tooki at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            PanelNavigationSettings(app: app)

            SettingsSection("Configuration", footerTitle: "Configuration notes") {
                SettingsRow("Folder") {
                    Text(StoragePaths.configDirectory.path(percentEncoded: false))
                        .font(SettingsTheme.controlFont.monospaced())
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                SettingsCardRow {
                    HStack {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([app.config.fileURL])
                        }
                        SettingsReloadButton {
                            app.reloadFromDisk()
                            return app.loadErrors.isEmpty
                        }
                    }
                }
                ForEach(app.loadErrors, id: \.self) { error in
                    SettingsCardRow {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text("config.json and snippets.json can live in your dotfiles. Symlink the folder or set TOOKI_CONFIG_DIR. Edits made outside Tooki are picked up automatically.")
            }

            URLSchemeSection()
        }
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
