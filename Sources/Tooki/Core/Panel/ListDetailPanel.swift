import SwiftUI

/// What the bottom bar of a `ListDetailPanel` shows.
struct ListDetailFooter {
    let title: String
    let icon: PanelIcon
    /// `nil` hides the main action, e.g. when nothing is selected.
    let primaryActionTitle: String?
    var primaryShortcut = "↵"
    var secondaryAction: FooterAction?
    var accessory: AnyView?
}

/// A Raycast-style panel: search on top, list and detail side by side, actions along the bottom,
/// and a ⌘K popup. Clipboard, snippets and the shelf manager all use it.
///
/// Handles the keys every such panel shares: arrows and Page Up/Down/Home/End move through the list
/// (or the popup), ↵ runs the main action (⌘↵ the second one), ⌘K toggles the popup, ← leaves a
/// submenu, ⌘P opens the filter menu and Esc closes one level at a time. Anything else goes to `onShortcut`.
struct ListDetailPanel<Action: PanelActionItem, Accessory: View, ListContent: View, Detail: View, Empty: View>: View {
    let placeholder: String
    @Binding var query: String
    let actions: ActionsMenu<Action>
    let footer: ListDetailFooter
    /// `false` shows `emptyState` across the whole panel instead of the list and detail.
    let hasItems: Bool
    var showsActions = true
    let onMove: (_ offset: Int) -> Void
    /// ↵ outside the popup. `isCommand` is true for ⌘↵.
    let onReturn: (_ isCommand: Bool) -> Void
    let onRunAction: (Action) -> Void
    let onShortcut: (KeyPress) -> KeyPress.Result
    let onCancel: () -> Void
    /// Usually a `PanelFilterMenu`, given whether its popup is open.
    @ViewBuilder let accessory: (_ isFilterOpen: Binding<Bool>) -> Accessory
    @ViewBuilder let list: ListContent
    @ViewBuilder let detail: Detail
    @ViewBuilder let emptyState: Empty

    @ViewState private var isFilterOpen = false

    private static var pageSize: Int { 8 }

    var body: some View {
        PanelLayout {
            SearchHeader(placeholder: placeholder, query: $query,
                         isSearchActive: !(actions.isShowing && hasItems) && !isFilterOpen, onKey: handleKey) {
                accessory($isFilterOpen)
            }
        } content: {
            content
                .simultaneousGesture(TapGesture().onEnded { isFilterOpen = false })
        } footer: {
            BottomActionBar(
                title: footer.title,
                icon: footer.icon,
                primaryActionTitle: footer.primaryActionTitle,
                primaryShortcut: footer.primaryShortcut,
                onPrimaryAction: { onReturn(false) },
                secondaryAction: footer.secondaryAction,
                onShowActions: hasItems && showsActions ? { actions.toggle() } : nil,
                accessory: footer.accessory
            )
        }
        .actionsPopup(isPresented: actions.isShowing && hasItems, onDismiss: actions.close) {
            ActionsPopup(
                title: actions.submenu?.title,
                actions: actions.visibleActions,
                selection: actions.selection,
                query: Bindable(actions).query,
                searchPrompt: actions.submenu == nil ? "Search for actions…" : "Search…",
                onKey: handleKey,
                onRun: onRunAction
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if hasItems {
            HStack(spacing: 0) {
                list.frame(width: PanelTheme.listWidth)
                PanelTheme.separator.frame(width: 1)
                detail
            }
        } else {
            // Fills the whole panel, so the message sits in the middle instead of beside an empty list.
            emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let offset = navigationOffset(for: press.key) {
            if actions.isShowing { actions.moveSelection(by: offset) } else { onMove(offset) }
            return .handled
        }
        // Holding Return or a shortcut must not run it repeatedly.
        guard press.phase == .down else { return .ignored }
        switch press.key {
        case .escape:
            if !actions.dismiss() { onCancel() }
        case .leftArrow where actions.submenu != nil && actions.query.isEmpty:
            _ = actions.dismiss()
        case .return:
            if actions.isShowing {
                if let action = actions.selectedAction { onRunAction(action) }
            } else {
                onReturn(press.modifiers.contains(.command))
            }
        default:
            let key = press.modifiers.contains(.command) ? press.characters.lowercased() : ""
            if key == "k" {
                if hasItems && showsActions { actions.toggle() }
            } else if key == "p", !press.modifiers.contains(.shift) {
                actions.close()
                isFilterOpen.toggle()
            } else {
                return onShortcut(press)
            }
        }
        return .handled
    }

    /// Arrows move one row, Page Up/Down a page, Home/End to the ends. These repeat while held.
    private func navigationOffset(for key: KeyEquivalent) -> Int? {
        switch key {
        case .upArrow: -1
        case .downArrow: 1
        case .pageUp: -Self.pageSize
        case .pageDown: Self.pageSize
        case .home: -Int.max / 2
        case .end: Int.max / 2
        default: nil
        }
    }
}
