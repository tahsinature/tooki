import SwiftUI
import TookiKit

/// Clipboard history: search on top, list and preview side by side, actions along the bottom.
struct ClipboardPanelView: View {
    @Bindable var model: ClipboardPanelModel
    let onAction: (ClipboardAction.Kind) -> Void
    /// Esc after the actions menu has handled its own back navigation.
    let onCancel: () -> Void
    /// Closes the panel after an entry is dragged out.
    let onClose: () -> Void

    var body: some View {
        ListDetailPanel(
            placeholder: "Search clipboard…",
            query: $model.query,
            actions: model.actions,
            footer: footer,
            hasItems: model.selectedItem != nil,
            onMove: model.moveSelection,
            onReturn: { isCommand in onAction(isCommand ? .paste : .copy) },
            onRunAction: { onAction($0.kind) },
            onShortcut: handleShortcut,
            onCancel: onCancel
        ) { isFilterOpen in
            PanelFilterMenu(
                selection: $model.typeFilter,
                isOpen: isFilterOpen,
                allTitle: "All Types",
                filterTitle: "Filter by Type",
                options: ClipboardContentType.allCases.map { ($0, $0.pluralLabel) }
            )
        } list: {
            ClipboardListView(model: model, onCopy: { onAction(.copy) })
        } detail: {
            if let item = model.selectedItem {
                ClipboardDetailView(item: item)
            }
        } emptyState: {
            emptyState
        }
        .environment(\.compactPanelLayout, true)
    }

    private var footer: ListDetailFooter {
        var footer = ListDetailFooter(
            title: model.itemCountLabel,
            icon: .symbol("doc.on.clipboard"),
            primaryActionTitle: model.selectedItem?.canBeUsed == true ? "Copy" : nil
        )
        if let item = model.selectedItem {
            footer.accessory = AnyView(
                ClipboardDragButton(item: item, onDropped: onClose)
                    .disabled(!item.canBeUsed)
            )
        }
        return footer
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.history.items.isEmpty {
            ContentUnavailableView(
                "Nothing Copied Yet",
                systemImage: "doc.on.clipboard",
                description: Text("Copy text, links, colors, images or files and they'll appear here.")
            )
        } else {
            ContentUnavailableView(
                "No Matching Entries",
                systemImage: "magnifyingglass",
                description: Text("Try a different search or type.")
            )
        }
    }

    private func handleShortcut(_ press: KeyPress) -> KeyPress.Result {
        let key = press.characters.lowercased()
        let command = press.modifiers.contains(.command)
        if press.key == .rightArrow, model.actions.isShowing, model.actions.query.isEmpty,
           let kind = model.actions.selectedAction?.kind, kind == .openWith || kind == .addToShelf {
            onAction(kind)
        } else if command, key == "y" {
            onAction(.preview)
        } else if command, key == "s" {
            onAction(.addToShelf)
        } else if command, key == "o" {
            model.showOpenWith()
        } else if command, key == "p" {
            onAction(.togglePin)
        } else if press.modifiers.contains(.control), key == "x" || press.characters == "\u{18}" {
            onAction(.delete)
        } else {
            return .ignored
        }
        return .handled
    }
}
