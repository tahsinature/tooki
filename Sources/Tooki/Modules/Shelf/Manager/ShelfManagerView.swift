import SwiftUI

/// Shelves: pick a shelf, then browse, open and manage its items.
struct ShelfManagerView: View {
    @Bindable var model: ShelfManagerModel
    let onAction: (ShelfManagerAction.Kind) -> Void
    let onCancel: () -> Void

    var body: some View {
        ListDetailPanel(
            placeholder: model.openShelf.map { "Search \($0.name)…" } ?? "Search shelves…",
            query: $model.query,
            actions: model.actions,
            footer: ListDetailFooter(
                title: model.openShelf?.name ?? "Shelves",
                icon: .symbol("tray.full"),
                primaryActionTitle: model.openShelf == nil ? "Open Shelf" : "Open"
            ),
            hasItems: hasItems,
            onMove: model.moveSelection,
            onReturn: { isCommand in onAction(primaryAction(isCommand: isCommand)) },
            onRunAction: { onAction($0.kind) },
            onShortcut: handleShortcut,
            onCancel: onCancel
        ) { _ in
            EmptyView()
        } list: {
            ShelfManagerList(model: model, onDoubleClick: { onAction(primaryAction(isCommand: false)) })
        } detail: {
            if let shelf = model.openShelf {
                if let item = model.selectedItem { ShelfManagerItemDetail(item: item, shelf: shelf) }
            } else if let shelf = model.selectedShelf {
                ShelfManagerShelfDetail(shelf: shelf)
            }
        } emptyState: {
            emptyState
        }
    }

    private var hasItems: Bool {
        model.openShelf == nil ? model.selectedShelf != nil : model.selectedItem != nil
    }

    private func primaryAction(isCommand: Bool) -> ShelfManagerAction.Kind {
        if model.openShelf != nil { return .open }
        return isCommand ? .showShelf : .openShelf
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.library.isEmpty {
            ContentUnavailableView(
                "No Shelves",
                systemImage: "tray",
                description: Text("Hold Shift while dragging files to start a shelf.")
            )
        } else {
            ContentUnavailableView(
                "No Matches",
                systemImage: "magnifyingglass",
                description: Text(model.openShelf == nil ? "Try a different search." : "Try a different search, or press Esc to go back.")
            )
        }
    }

    private func handleShortcut(_ press: KeyPress) -> KeyPress.Result {
        let key = press.characters.lowercased()
        let command = press.modifiers.contains(.command)
        let shift = press.modifiers.contains(.shift)
        let isControlX = key == "\u{18}" || (key == "x" && press.modifiers.contains(.control))
        let kind: ShelfManagerAction.Kind?
        if model.openShelf == nil {
            kind = isControlX ? .closeShelf : nil
        } else {
            kind = switch key {
            case _ where press.key == .rightArrow:
                model.actions.isShowing && model.actions.query.isEmpty && model.actions.selectedAction?.kind == .openWith
                    ? .openWith : nil
            case "o" where command: .openWith
            case "y" where command: .quickLook
            case "f" where command && shift: .showInFinder
            case "c" where command: shift ? .copyPath : .copyFile
            case "r" where command: .rename
            case _ where isControlX: .remove
            default: nil
            }
        }
        guard let kind else { return .ignored }
        onAction(kind)
        return .handled
    }
}
