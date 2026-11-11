import SwiftUI
import TookiKit

/// Snippets: search on top, list and preview side by side, actions along the bottom.
/// Creating or editing swaps the whole panel for a form.
struct SnippetPanelView: View {
    @Bindable var model: SnippetPanelModel
    let onAction: (SnippetAction.Kind) -> Void
    let onCancel: () -> Void

    var body: some View {
        if model.form != nil {
            SnippetFormView(model: model, onBack: { model.form = nil }, onSave: save)
        } else {
            browser
        }
    }

    private var browser: some View {
        ListDetailPanel(
            placeholder: "Search snippets…",
            query: $model.query,
            actions: model.actions,
            footer: ListDetailFooter(
                title: "Snippets",
                icon: .symbol("text.quote"),
                primaryActionTitle: model.selectedSnippet == nil ? "Create Snippet" : "Copy to Clipboard",
                primaryShortcut: model.selectedSnippet == nil ? "⌘N" : "↵",
                // With nothing selected, creating is already the main action.
                secondaryAction: model.selectedSnippet == nil ? nil : FooterAction(title: "Create Snippet", shortcut: "⌘N") { onAction(.create) }
            ),
            hasItems: model.selectedSnippet != nil,
            onMove: model.moveSelection,
            onReturn: { isCommand in
                if model.selectedSnippet == nil { onAction(.create) } else { onAction(isCommand ? .paste : .copy) }
            },
            onRunAction: { onAction($0.kind) },
            onShortcut: handleShortcut,
            onCancel: onCancel
        ) { isFilterOpen in
            if !model.collections.isEmpty {
                PanelFilterMenu(
                    selection: $model.collectionFilter,
                    isOpen: isFilterOpen,
                    allTitle: "All Collections",
                    options: model.collections.map { ($0, $0) }
                )
            }
        } list: {
            SnippetListView(model: model, onCopy: { onAction(.copy) })
        } detail: {
            if let snippet = model.selectedSnippet {
                SnippetDetailView(snippet: snippet, usage: model.usage.entry(for: snippet.id))
            }
        } emptyState: {
            emptyState
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.snippets.value.isEmpty {
            ContentUnavailableView(
                "No Snippets Yet",
                systemImage: "text.quote",
                description: Text("Press ⌘N to write text you use often, then copy, paste or expand it by keyword.")
            )
        } else {
            ContentUnavailableView(
                "No Matching Snippets",
                systemImage: "magnifyingglass",
                description: Text("Try a different search or collection.")
            )
        }
    }

    private func save() {
        if !model.saveDraft() { NSSound.beep() }
    }

    private func handleShortcut(_ press: KeyPress) -> KeyPress.Result {
        let key = press.characters.lowercased()
        let command = press.modifiers.contains(.command)
        let kind: SnippetAction.Kind? = switch key {
        case _ where press.key == .rightArrow:
            model.actions.isShowing && model.actions.query.isEmpty && model.actions.selectedAction?.kind == .openWith
                ? .openWith : nil
        case "o" where command: .openWith
        case "p" where command: .togglePin
        case "e" where command: .edit
        case "d" where command: .duplicate
        case "n" where command: .create
        case "x" where press.modifiers.contains(.control), "\u{18}": .delete
        default: nil
        }
        guard let kind else { return .ignored }
        onAction(kind)
        return .handled
    }
}
