import AppKit
import TookiKit

/// Shows the clipboard history panel and carries out the chosen action.
@MainActor
final class ClipboardPanelController {
    private var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
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
        let panel = FloatingPanel(size: PanelTheme.listDetailSize) {
            ClipboardPanelView(
                model: model,
                onAction: { [weak self, weak model] kind in
                    guard let model else { return }
                    self?.perform(kind, model: model)
                },
                onCancel: { [weak self] in self?.dismiss() },
                onClose: { [weak self] in self?.close() }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            if model?.actions.dismiss() != true { self?.dismiss() }
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

    private func perform(_ kind: ClipboardAction.Kind, model: ClipboardPanelModel) {
        guard let item = model.selectedItem else { return }
        let needsUsableItem = switch kind {
        case .paste, .copy, .open, .openWith: true
        case .togglePin, .delete: false
        }
        if needsUsableItem, !item.canBeUsed {
            NSSound.beep()
            return
        }
        if kind == .openWith {
            model.showOpenWith()
            return
        }
        model.actions.close()
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
