import AppKit
import TookiKit

/// Shows the floating launcher and runs the chosen item in the app you were using.
@MainActor
final class SearchPanelController {
    enum Mode {
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

    private var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    /// Runs on ⌘, after the panel closes.
    var onOpenSettings: (() -> Void)?
    private var shownMode: Mode?
    private var history = LaunchHistoryFile.load()

    func isShowing(_ mode: Mode) -> Bool {
        panel?.isVisible == true && shownMode == mode
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
                onRun: { [weak self] action, item in self?.run(action, of: item) },
                onCancel: { [weak self] in self?.dismiss() },
                onOpenSettings: { [weak self] in
                    self?.close()
                    self?.onOpenSettings?()
                }
            )
        }
        // Esc closes the ⌘K popup first, like in the clipboard panel.
        panel.onEscape = { [weak self, weak model] in
            if model?.isShowingActions == true { model?.isShowingActions = false } else { self?.dismiss() }
        }
        self.panel = panel
        panel.present()
    }

    func close() {
        panel?.close()
        panel = nil
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
