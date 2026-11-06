import AppKit
import SwiftUI

struct SettingsSidebar: View {
    let app: AppController
    @Binding var selection: SettingsPage?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(BuildInfo.appName).font(.title2.bold())
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            List(selection: $selection) {
                Section {
                    ForEach(SettingsPage.modules) { page in
                        SidebarRow(page: page)
                    }
                }
                Section {
                    ForEach(SettingsPage.appPages) { page in
                        SidebarRow(page: page)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            SidebarAppCard(updater: app.updater, isSelected: selection == .about) { selection = .about }
                .padding(10)
        }
        .background(SettingsTheme.sidebar.ignoresSafeArea())
    }
}

private struct SidebarRow: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: page.icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SettingsTheme.secondaryText)
                .frame(width: 22)
            Text(page.title)
                .foregroundStyle(Color(red: 0.92, green: 0.88, blue: 0.97))
        }
        .padding(.vertical, 7)
        .tag(page)
        .listRowSeparator(.hidden)
    }
}

/// The app's own card at the bottom of the sidebar, like the account row in System Settings.
/// Its subtitle tells dev and release builds apart. Opens About.
private struct SidebarAppCard: View {
    let updater: Updater
    let isSelected: Bool
    let action: () -> Void
    @ViewState private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(BuildInfo.appName).font(.headline)
                    if case .installing = updater.state {
                        Text("Installing… Tooki will restart")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        BuildLabel()
                    }
                }
                Spacer(minLength: 0)
                if updater.shouldPrompt {
                    Text("Update")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(SettingsTheme.accent, in: .capsule)
                        .help("A new version of Tooki is available")
                }
            }
            .padding(8)
            .contentShape(.rect)
            .background(background, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var background: Color {
        if isSelected { return SettingsTheme.accent.opacity(0.2) }
        return isHovered ? .primary.opacity(0.05) : .clear
    }
}

