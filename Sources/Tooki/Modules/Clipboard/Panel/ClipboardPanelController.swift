import AppKit
import TookiKit

/// Shows the clipboard history panel and carries out the chosen action.
@MainActor
final class ClipboardPanelController: ResumablePanelController {
    var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    private let history: ClipboardHistory
    private let shelves: ShelfWindows
    private let groupByDate: () -> Bool

    init(history: ClipboardHistory, shelves: ShelfWindows, groupByDate: @escaping () -> Bool = { true }) {
        self.history = history
        self.shelves = shelves
        self.groupByDate = groupByDate
    }

    func toggle() {
        if isShowing {
            close()
        } else if !resume() {
            show()
        }
    }

    func show() {
        panel?.close()
        let model = ClipboardPanelModel(
            history: history,
            targetAppName: NSWorkspace.shared.frontmostApplication?.localizedName,
            groupByDate: groupByDate
        )
        let panel = FloatingPanel(size: PanelTheme.size) {
            ClipboardPanelView(
                model: model,
                onAction: { [weak self, weak model] kind in
                    guard let model else { return }
                    self?.perform(kind, model: model)
                },
                onCancel: { [weak self, weak model] in
                    if let model { self?.escape(model) }
                },
                onClose: { [weak self] in self?.close() }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            if let model { self?.escape(model) }
        }
        panel.quickLook = QuickLookPreview()
        panel.onPresent = { [weak model] in
            if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                model?.targetAppName = app.localizedName
            }
        }
        panel.onClose = { [weak model] in
            model?.selectedID = model?.selectedItem?.id
        }
        self.panel = panel
        panel.present()
    }

    private func escape(_ model: ClipboardPanelModel) {
        if model.actions.dismiss() { return }
        if !model.query.isEmpty {
            model.query = ""
        } else {
            dismiss()
        }
    }

    /// Esc with nothing left to back out of.
    private func dismiss() {
        close()
        onBack?()
    }

    private func perform(_ kind: ClipboardAction.Kind, model: ClipboardPanelModel) {
        guard let item = model.selectedItem else { return }
        let needsUsableItem = switch kind {
        case .paste, .copy, .copyPath, .preview, .open, .openWith, .addToShelf, .addTo, .add: true
        case .togglePin, .delete: false
        }
        if needsUsableItem, !item.canBeUsed {
            NSSound.beep()
            return
        }
        switch kind {
        case .openWith:
            return model.showOpenWith()
        case .addToShelf:
            return model.actions.showSubmenu(title: "Add to Shelf", actions: ClipboardAction.shelves(in: shelves.library), parentID: .addToShelf)
        case .addTo(let destination) where item.files != nil:
            return model.actions.showSubmenu(title: "Add Files", actions: ClipboardAction.modes(for: destination), parentID: kind)
        default:
            break
        }
        model.actions.close()
        switch kind {
        case .preview:
            panel?.quickLook?.toggle(ClipboardFileURLs.urls(for: item))
        case .copyPath:
            let paths = ClipboardFileURLs.urls(for: item).map(\.path)
            guard !paths.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
            close()
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
        case .addTo(let destination):
            // Only text, links and images get here; they're saved as new files either way.
            addToShelf(item, destination: destination, mode: .copy)
        case .add(let destination, let mode):
            addToShelf(item, destination: destination, mode: mode)
        case .openWith, .addToShelf:
            break
        }
    }

    /// Adds the item the same way dropping it on the shelf would. The clipboard panel stays open.
    private func addToShelf(_ item: ClipboardItem, destination: ShelfDestination, mode: ShelfAddMode) {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects(ClipboardDragContent.writers(for: item))
        shelves.add(from: pasteboard, mode: mode, to: destination)
    }
}
