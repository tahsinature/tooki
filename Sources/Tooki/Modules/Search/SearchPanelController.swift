import AppKit
import TookiKit

/// Shows the floating search panel and runs the chosen item in the app you were using.
@MainActor
final class SearchPanelController {
    enum Mode {
        case everything
        case clipboard
        case menuBar

        var placeholder: String {
            switch self {
            case .everything: "Search snippets, clipboard and commands"
            case .clipboard: "Search clipboard history"
            case .menuBar: "Search menu bar items"
            }
        }

        var hint: String {
            self == .menuBar ? "↵ Click item    esc Close" : "↵ Paste    ⌘↵ Copy    esc Close"
        }
    }

    private var panel: FloatingPanel?
    private var shownMode: Mode?

    func isShowing(_ mode: Mode) -> Bool {
        panel?.isVisible == true && shownMode == mode
    }

    /// Pressing the same hotkey again while the panel is open closes it.
    func toggle(_ mode: Mode, items: [SearchItem]) {
        if isShowing(mode) {
            close()
        } else {
            show(mode, items: items)
        }
    }

    func show(_ mode: Mode, items: [SearchItem]) {
        panel?.close()
        shownMode = mode
        let model = SearchModel(items: items, placeholder: mode.placeholder, hint: mode.hint)
        let panel = FloatingPanel(size: CGSize(width: 640, height: 420)) {
            SearchView(
                model: model,
                onSubmit: { [weak self] item, copyOnly in self?.submit(item, copyOnly: copyOnly) },
                onCancel: { [weak self] in self?.close() }
            )
        }
        self.panel = panel
        panel.present()
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func submit(_ item: SearchItem, copyOnly: Bool) {
        close()
        if copyOnly {
            item.copy?()
            return
        }
        Task {
            // Let focus return to the previous app before typing into it.
            try? await Task.sleep(for: .milliseconds(80))
            item.run()
        }
    }
}
