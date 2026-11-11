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
        if model.renamingShelf != nil {
            model.finishRenaming(save: false)
        } else if model.openShelf != nil {
            model.closeOpenShelf()
        } else {
            close()
            onBack?()
        }
    }

    private func perform(_ kind: ShelfManagerAction.Kind, model: ShelfManagerModel) {
        switch kind {
        case .toggleShelves:
            model.actions.close()
            if let shelf = model.openShelf {
                windows.isVisible(shelf) ? windows.hide(shelf) : windows.show(shelf)
            } else {
                windows.isAnyVisible ? windows.hideAll() : windows.showAll()
            }
            return
        case .newShelf:
            // Without focus: focusing the new shelf would close this panel.
            model.select(windows.newShelf(focus: false))
            return
        default:
            break
        }
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
        case .renameShelf:
            model.startRenaming(shelf)
        case .closeShelf where shelf.hasCopies:
            model.actions.showSubmenu(title: "Close “\(shelf.name)”?", actions: ShelfManagerAction.closeConfirmation, parentID: .closeShelf)
        case .closeShelf, .confirmClose:
            model.actions.close()
            windows.close(shelf)
        case .cancelClose:
            _ = model.actions.dismiss()
        case .pasteFromClipboard where Self.clipboardHasFiles:
            model.actions.showSubmenu(title: "Paste Files", actions: ShelfManagerAction.pasteModes, parentID: .pasteFromClipboard)
        case .pasteFromClipboard:
            model.actions.close()
            windows.add(from: .general, mode: .copy, to: .existing(shelf.id))
        case .paste(let mode):
            model.actions.close()
            windows.add(from: .general, mode: mode, to: .existing(shelf.id))
        default:
            break
        }
    }

    private static var clipboardHasFiles: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
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
