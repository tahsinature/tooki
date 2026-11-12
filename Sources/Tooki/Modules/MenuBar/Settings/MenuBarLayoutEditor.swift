import SwiftUI
import TookiKit

/// Settings → Menu Bar → Layout: reorder icons and choose their sections, then apply.
struct MenuBarLayoutEditor: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let organizer: MenuBarOrganizer
    let arranger: MenuBarArranger
    @ViewState private var model = MenuBarLayoutEditorModel()

    var body: some View {
        SettingsSection("Layout") {
            SettingsCardRow {
                layoutList
            }
            SettingsCardRow {
                actions
            }
            SettingsToggleRow("Restore this layout when macOS moves icons", isOn: $config.value.menuBar.restoreLayout)
        } footer: {
            footer
        }
    }

    private var layoutList: some View {
        List {
            if organizer.hasAlwaysHiddenSection {
                Section("Always Hidden (top is leftmost)") {
                    ForEach(model.alwaysHidden) { row($0, in: .alwaysHidden) }
                        .onMove { model.alwaysHidden.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            Section("Hidden") {
                ForEach(model.hidden) { row($0, in: .hidden) }
                    .onMove { model.hidden.move(fromOffsets: $0, toOffset: $1) }
            }
            Section("Shown") {
                ForEach(model.shown) { row($0, in: .shown) }
                    .onMove { model.shown.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .scrollContentBackground(.hidden)
        .frame(height: listHeight)
        .task(id: [organizer.isInstalled, organizer.hasAlwaysHiddenSection]) { await load() }
    }

    private var actions: some View {
        HStack {
            Button("Reload from Menu Bar") { Task { await load(fromMenuBar: true) } }
            Button("Forget Missing Apps") { model.removeMissing() }
            Spacer()
            if arranger.isArranging { ProgressView().controlSize(.small) }
            Button("Apply & Save", action: applyAndSave)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .disabled(arranger.isArranging || !organizer.isInstalled)
    }

    private var listHeight: CGFloat {
        let rows = CGFloat(model.alwaysHidden.count + model.hidden.count + model.shown.count)
        return min(max(rows * 28 + 70, 160), 440)
    }

    private func row(_ row: MenuBarLayoutRow, in section: MenuBarSection) -> some View {
        HStack(spacing: 8) {
            MenuBarLayoutRowIcon(row: row)
            Text(row.title)
            if !row.isRunning {
                Text("Not running").font(.caption).foregroundStyle(.secondary)
            }
            if model.underNotch.contains(row.id) {
                Label("Under the notch", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            ForEach(destinations(from: section), id: \.self) { destination in
                Button(Self.moveTitle(destination)) { model.move(row, to: destination) }
                    .buttonStyle(InteractionButtonStyle(horizontalPadding: 4, verticalPadding: 4))
            }
        }
        .opacity(row.isRunning ? 1 : 0.5)
    }

    private func destinations(from section: MenuBarSection) -> [MenuBarSection] {
        MenuBarSection.allCases.filter { $0 != section && ($0 != .alwaysHidden || organizer.hasAlwaysHiddenSection) }
    }

    private static func moveTitle(_ section: MenuBarSection) -> String {
        switch section {
        case .alwaysHidden: "Always Hide"
        case .hidden: "Hide"
        case .shown: "Show"
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !organizer.isInstalled {
                Text("Turn on “Organize menu bar icons” to arrange icons.")
            }
            if let app = arranger.conflictingApp {
                Text("\(app) is running and may move icons back. Quit it while using Tooki’s layout.")
                    .foregroundStyle(.orange)
            }
            if let status = arranger.status {
                Text(status).foregroundStyle(.orange)
            }
            Text("Drag rows to reorder. Apply moves the icons for you without taking over the mouse pointer. Control Center and the clock always stay on the right.")
        }
    }

    private func load(fromMenuBar: Bool = false) async {
        await model.load(saved: config.value.menuBar.layout, organizer: organizer, fromMenuBar: fromMenuBar)
    }

    private func applyAndSave() {
        let layout = model.layout
        config.value.menuBar.layout = layout
        Task {
            await arranger.arrange(layout)
            await load()
        }
    }
}

private struct MenuBarLayoutRowIcon: View {
    let row: MenuBarLayoutRow

    var body: some View {
        if !row.isAppleItem, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: row.bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "menubar.rectangle")
                .frame(width: 18, height: 18)
        }
    }
}
