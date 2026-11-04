import AppKit
import TookiKit

/// Shows the clipboard history panel and carries out the chosen action.
@MainActor
final class ClipboardPanelController {
    private var panel: FloatingPanel?
    private let history: ClipboardHistory

    init(history: ClipboardHistory) {
        self.history = history
    }

    var isShowing: Bool { panel?.isVisible == true }

    func toggle() {
        isShowing ? close() : show()
    }

    func show() {
        panel?.close()
        let model = ClipboardPanelModel(
            history: history,
            targetAppName: NSWorkspace.shared.frontmostApplication?.localizedName
        )
        let panel = FloatingPanel(size: CGSize(width: 780, height: 480)) {
            ClipboardPanelView(
                model: model,
                onAction: { [weak self, weak model] kind in
                    guard let model else { return }
                    self?.perform(kind, model: model)
                },
                onCancel: { [weak self] in self?.close() }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            if model?.dismissMenu() != true { self?.close() }
        }
        self.panel = panel
        panel.present()
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func perform(_ kind: ClipboardAction.Kind, model: ClipboardPanelModel) {
        guard let item = model.selectedItem else { return }
        if kind == .openWith {
            model.showOpenWith()
            return
        }
        model.isShowingActions = false
        switch kind {
        case .paste:
            close()
            Task {
                // Let focus return to the previous app before pasting into it.
                try? await Task.sleep(for: .milliseconds(80))
                history.paste(item)
            }
        case .copy:
            close()
            history.copy(item)
        case .togglePin:
            model.togglePinOfSelected()
        case .delete:
            model.deleteSelected()
        case .open(let appURL):
            close()
            ClipboardOpenWith.open(item, with: appURL)
        case .openWith:
            break
        }
    }
}
