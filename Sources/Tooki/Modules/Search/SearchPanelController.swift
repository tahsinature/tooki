import AppKit
import TookiKit

/// Shows the floating launcher and runs the chosen item in the app you were using.
@MainActor
final class SearchPanelController: ResumablePanelController {
    enum Mode: Hashable {
        case everything
        case menuBar

        var placeholder: String {
            switch self {
            case .everything: "Search for apps and commands…"
            case .menuBar: "Search menu bar items…"
            }
        }

        var title: String {
            switch self {
            case .everything: "Tooki"
            case .menuBar: "Menu Bar"
            }
        }

        var filterGroups: [SearchItem.Group] {
            switch self {
            case .everything: [.applications, .commands]
            case .menuBar: []
            }
        }

        var icon: PanelIcon {
            switch self {
            case .everything: .symbol("magnifyingglass")
            case .menuBar: .symbol("menubar.rectangle")
            }
        }
    }

    var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    /// Runs on ⌘, after the panel closes.
    var onOpenSettings: (() -> Void)?
    var refreshItems: (() -> [SearchItem])?
    var refreshMenuBarItems: (() async -> [SearchItem])?
    private var shownMode: Mode?
    private var savedPanels: [Mode: FloatingPanel] = [:]
    private var history = LaunchHistoryFile.load()

    func isShowing(_ mode: Mode) -> Bool {
        panel?.isVisible == true && shownMode == mode
    }

    /// Back navigation restores the parent search; an explicit show starts a fresh one.
    @discardableResult
    func resume(_ mode: Mode) -> Bool {
        guard let saved = savedPanels[mode] else { return false }
        panel?.close()
        panel = saved
        shownMode = mode
        QuickLookPreview.closeCurrent()
        saved.present(restoring: true)
        return true
    }

    /// Pressing the same hotkey again while the panel is open closes it.
    func toggle(_ mode: Mode, items: [SearchItem], calculate: @escaping (String) -> SearchItem? = { _ in nil }) {
        if isShowing(mode) {
            close()
        } else {
            show(mode, items: items, calculate: calculate)
        }
    }

    func show(_ mode: Mode, items: [SearchItem], calculate: @escaping (String) -> SearchItem? = { _ in nil }) {
        panel?.close()
        shownMode = mode
        let model = SearchModel(
            items: items,
            placeholder: mode.placeholder,
            title: mode.title,
            icon: mode.icon,
            filterGroups: mode.filterGroups,
            history: history,
            calculate: calculate
        )
        let panel = FloatingPanel(size: SearchView.size) {
            SearchView(
                model: model,
                onRun: { [weak self, weak model] action, item in
                    model?.isShowingActions = false
                    self?.run(action, of: item)
                },
                onCancel: { [weak self, weak model] in
                    if let model { self?.escape(model) }
                },
                onOpenSettings: { [weak self] in
                    self?.close()
                    self?.onOpenSettings?()
                }
            )
        }
        // Esc closes the ⌘K popup first, like in the clipboard panel.
        panel.onEscape = { [weak self, weak model] in
            if let model { self?.escape(model) }
        }
        if mode == .everything {
            panel.onPresent = { [weak self, weak model] in
                guard let self, let items = refreshItems?() else { return }
                model?.refresh(items: items, history: history)
            }
        } else {
            panel.onPresent = { [weak self, weak model, weak panel] in
                guard let refresh = self?.refreshMenuBarItems else { return }
                Task { [weak self, weak model, weak panel] in
                    let items = await refresh()
                    guard let self, let panel, self.panel === panel, panel.isVisible else { return }
                    model?.refresh(items: items, history: history)
                }
            }
        }
        self.panel = panel
        savedPanels[mode] = panel
        panel.present()
    }

    private func escape(_ model: SearchModel) {
        if model.isShowingActions {
            model.isShowingActions = false
        } else if !model.query.isEmpty {
            model.query = ""
        } else if model.groupFilter != nil {
            model.groupFilter = nil
        } else {
            dismiss()
        }
    }

    /// Esc with nothing left to back out of.
    private func dismiss() {
        close()
        onBack?()
    }

    private func run(_ action: SearchAction, of item: SearchItem) {
        close()
        history.record(item.id)
        LaunchHistoryFile.save(history)
        Task {
            // Let focus return to the previous app before typing into it.
            try? await Task.sleep(for: .milliseconds(80))
            action.run()
        }
    }
}

/// Keeps the launcher's ranking history between launches. Private to this Mac.
private enum LaunchHistoryFile {
    static let url = StoragePaths.dataDirectory.appending(path: "launcher-history.json")

    static func load() -> LaunchHistory {
        JSONFile.read(url).flatMap { try? JSONFile.decoder.decode(LaunchHistory.self, from: $0) } ?? LaunchHistory()
    }

    static func save(_ history: LaunchHistory) {
        guard let data = try? JSONFile.encoder.encode(history) else { return }
        try? JSONFile.write(data, to: url)
    }
}
