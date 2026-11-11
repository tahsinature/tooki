import AppKit

/// Shows the shelf manager and carries out the chosen action.
@MainActor
final class ShelfManagerController {
    private var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    private let windows: ShelfWindows

    init(windows: ShelfWindows) {
        self.windows = windows
    }

    var isShowing: Bool { panel?.isVisible == true }

    func toggle(library: ShelfLibrary) {
        isShowing ? close() : show(library: library)
    }

    func show(library: ShelfLibrary) {
        panel?.close()
        let model = ShelfManagerModel(library: library)
        let panel = FloatingPanel(size: PanelTheme.listDetailSize) {
            ShelfManagerView(
                model: model,
                onAction: { [weak self, weak model] kind in
                    guard let model else { return }
                    self?.perform(kind, model: model)
                },
                onCancel: { [weak self, weak model] in
                    guard let model else { return }
                    self?.back(model)
                }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            guard let model, !model.actions.dismiss() else { return }
            self?.back(model)
        }
        self.panel = panel
        panel.present()
    }

    func close() {
        panel?.close()
        panel = nil
    }

    /// Esc leaves an open shelf first, then closes the panel.
    private func back(_ model: ShelfManagerModel) {
        if model.openShelf != nil {
            model.closeOpenShelf()
        } else {
            close()
            onBack?()
        }
    }

    private func perform(_ kind: ShelfManagerAction.Kind, model: ShelfManagerModel) {
        if let shelf = model.openShelf {
            if let item = model.selectedItem { perform(kind, on: item, in: shelf, model: model) }
        } else if let shelf = model.selectedShelf {
            perform(kind, on: shelf, model: model)
        }
    }

    private func perform(_ kind: ShelfManagerAction.Kind, on shelf: Shelf, model: ShelfManagerModel) {
        switch kind {
        case .openShelf:
            model.open(shelf)
        case .showShelf:
            close()
            windows.show(shelf, focus: true)
        case .closeShelf where shelf.hasCopies:
            model.actions.showSubmenu(title: "Close “\(shelf.name)”?", actions: ShelfManagerAction.closeConfirmation, parentID: .closeShelf)
        case .closeShelf, .confirmClose:
            model.actions.close()
            windows.close(shelf)
        case .cancelClose:
            _ = model.actions.dismiss()
        default:
            break
        }
    }

    private func perform(_ kind: ShelfManagerAction.Kind, on item: ShelfItem, in shelf: Shelf, model: ShelfManagerModel) {
        if kind == .openWith {
            model.actions.showSubmenu(title: "Open With", actions: ShelfManagerAction.openWith(item), parentID: .openWith)
            return
        }
        model.actions.close()
        switch kind {
        case .open:
            close()
            NSWorkspace.shared.open(item.url)
        case .openIn(let appURL):
            close()
            NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        case .quickLook:
            // The shelf's own panel owns the preview, so bring the shelf up and preview there.
            close()
            windows.show(shelf, focus: true)
            shelf.onQuickLook([item.url])
        case .showInFinder:
            close()
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        case .copyFile:
            close()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([item.url as NSURL])
        case .copyPath:
            close()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        case .rename:
            close()
            ShelfRenamePrompt.run(for: item, on: shelf)
        case .remove:
            let ids = model.items.map(\.id)
            let index = ids.firstIndex(of: item.id) ?? 0
            shelf.remove([item.id])
            // Keep the keyboard working on the next item.
            model.selectedItemID = ids.indices.contains(index + 1) ? ids[index + 1] : ids.dropLast().last
        default:
            break
        }
    }
}
