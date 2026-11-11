import AppKit
import TookiKit

/// Shows the snippets panel and carries out the chosen action.
@MainActor
final class SnippetPanelController {
    private var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    private let snippets: JSONDocument<[Snippet]>
    private let usage: SnippetUsage
    private let inserter: SnippetInserter

    init(snippets: JSONDocument<[Snippet]>, usage: SnippetUsage, inserter: SnippetInserter) {
        self.snippets = snippets
        self.usage = usage
        self.inserter = inserter
    }

    var isShowing: Bool { panel?.isVisible == true }

    func toggle() {
        isShowing ? close() : show()
    }

    /// - Parameter creating: opens straight into the create form.
    func show(creating: Bool = false) {
        panel?.close()
        let model = SnippetPanelModel(
            snippets: snippets,
            usage: usage,
            targetAppName: NSWorkspace.shared.frontmostApplication?.localizedName
        )
        if creating { model.startCreating() }
        let panel = FloatingPanel(size: PanelTheme.listDetailSize) {
            SnippetPanelView(
                model: model,
                onAction: { [weak self, weak model] kind in
                    guard let model else { return }
                    self?.perform(kind, model: model)
                },
                onCancel: { [weak self] in self?.dismiss() }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            guard let model else { return }
            if model.form != nil {
                model.form = nil
            } else if !model.actions.dismiss() {
                self?.dismiss()
            }
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

    private func perform(_ kind: SnippetAction.Kind, model: SnippetPanelModel) {
        if kind == .create {
            model.startCreating()
            return
        }
        guard let snippet = model.selectedSnippet else { return }
        switch kind {
        case .openWith:
            model.actions.showSubmenu(title: "Open With", actions: SnippetOpenWith.actions(for: snippet), parentID: .openWith)
            return
        case .delete:
            model.actions.showSubmenu(title: "Delete “\(snippet.name)”?", actions: SnippetAction.deleteConfirmation, parentID: .delete)
            return
        case .cancelDelete:
            _ = model.actions.dismiss()
            return
        default:
            break
        }
        model.actions.close()
        switch kind {
        case .copy:
            close()
            usage.record(snippet.id)
            inserter.copy(snippet)
        case .paste:
            close()
            usage.record(snippet.id)
            // The inserter waits briefly, so focus is back in the previous app before pasting.
            inserter.insert(snippet)
        case .open(let appURL):
            close()
            SnippetOpenWith.open(snippet, with: appURL)
        case .togglePin:
            model.togglePinOfSelected()
        case .edit:
            model.startEditingSelected()
        case .duplicate:
            model.startDuplicatingSelected()
        case .confirmDelete:
            model.deleteSelected()
        case .cancelDelete, .create, .openWith, .delete:
            break
        }
    }
}
