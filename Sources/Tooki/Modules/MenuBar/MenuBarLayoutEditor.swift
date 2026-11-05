import SwiftUI
import TookiKit

/// Settings → Menu Bar → Layout: reorder icons and choose which are hidden, then apply.
struct MenuBarLayoutEditor: View {
    @Bindable var config: JSONDocument<TookiConfig>
    let organizer: MenuBarOrganizer
    let arranger: MenuBarArranger
    @ViewState private var model = MenuBarLayoutEditorModel()

    var body: some View {
        Section {
            List {
                Section("Shown (top is leftmost)") {
                    ForEach(model.shown) { row($0, isHidden: false) }
                        .onMove { model.shown.move(fromOffsets: $0, toOffset: $1) }
                }
                Section("Hidden") {
                    ForEach(model.hidden) { row($0, isHidden: true) }
                        .onMove { model.hidden.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .frame(height: listHeight)
            .task(id: organizer.isInstalled) { await load() }

            HStack {
                Button("Reload from Menu Bar") { Task { await load(fromMenuBar: true) } }
                Button("Forget Missing Apps") { model.removeMissing() }
                Spacer()
                if arranger.isArranging { ProgressView().controlSize(.small) }
                Button("Apply & Save", action: applyAndSave)
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(arranger.isArranging || !organizer.isInstalled)

            Toggle("Restore this layout when macOS moves icons", isOn: $config.value.menuBar.restoreLayout)
        } header: {
            Text("Layout")
        } footer: {
            footer
        }
    }

    private var listHeight: CGFloat {
        let rows = CGFloat(model.shown.count + model.hidden.count)
        return min(max(rows * 28 + 70, 160), 440)
    }

    private func row(_ row: MenuBarLayoutRow, isHidden: Bool) -> some View {
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
            Button(isHidden ? "Show" : "Hide") { model.toggleHidden(row) }
                .buttonStyle(.borderless)
        }
        .opacity(row.isRunning ? 1 : 0.5)
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
            Text("Drag rows to reorder. Apply moves the icons for you, briefly using the mouse pointer. Control Center and the clock always stay on the right.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func load(fromMenuBar: Bool = false) async {
        await model.load(saved: config.value.menuBar.layout, separatorFrame: organizer.separatorFrame, fromMenuBar: fromMenuBar)
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
