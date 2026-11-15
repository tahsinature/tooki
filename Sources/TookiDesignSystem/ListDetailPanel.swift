import SwiftUI

/// What the bottom bar of a `ListDetailPanel` shows.
public struct ListDetailFooter {
    public init(title: String, icon: PanelIcon, primaryActionTitle: String?, primaryShortcut: String = "↵",
                secondaryAction: FooterAction? = nil, accessory: AnyView? = nil) {
        self.title = title
        self.icon = icon
        self.primaryActionTitle = primaryActionTitle
        self.primaryShortcut = primaryShortcut
        self.secondaryAction = secondaryAction
        self.accessory = accessory
    }

    public let title: String
    public let icon: PanelIcon
    /// `nil` hides the main action, e.g. when nothing is selected.
    public let primaryActionTitle: String?
    public var primaryShortcut = "↵"
    public var secondaryAction: FooterAction?
    public var accessory: AnyView?
}

/// A Raycast-style panel: search on top, list and detail side by side, actions along the bottom,
/// and a ⌘K popup. Clipboard, snippets and the shelf manager all use it.
///
/// Handles the keys every such panel shares: arrows move rows, Page Up/Down moves a visible page,
/// and ⌘↑/↓ or Home/End jumps to the ends of the list
/// (or the popup), ↵ runs the main action (⌘↵ the second one), ⌘K toggles the popup, ← leaves a
/// submenu, ⌘P opens the filter menu and Esc closes one level at a time. Anything else goes to `onShortcut`.
public struct ListDetailPanel<Action: PanelActionItem, Accessory: View, ListContent: View, Detail: View, Empty: View>: View {
    let placeholder: String
    @Binding var query: String
    let actions: ActionsMenu<Action>
    let navigation: PanelKeyboardNavigation
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


    public init(placeholder: String, query: Binding<String>, actions: ActionsMenu<Action>, navigation: PanelKeyboardNavigation,
                footer: ListDetailFooter, hasItems: Bool, showsActions: Bool = true,
                onMove: @escaping (Int) -> Void, onReturn: @escaping (Bool) -> Void,
                onRunAction: @escaping (Action) -> Void, onShortcut: @escaping (KeyPress) -> KeyPress.Result,
                onCancel: @escaping () -> Void,
                @ViewBuilder accessory: @escaping (Binding<Bool>) -> Accessory,
                @ViewBuilder list: () -> ListContent, @ViewBuilder detail: () -> Detail, @ViewBuilder emptyState: () -> Empty) {
        self.placeholder = placeholder
        self._query = query
        self.actions = actions
        self.navigation = navigation
        self.footer = footer
        self.hasItems = hasItems
        self.showsActions = showsActions
        self.onMove = onMove
        self.onReturn = onReturn
        self.onRunAction = onRunAction
        self.onShortcut = onShortcut
        self.onCancel = onCancel
        self.accessory = accessory
        self.list = list()
        self.detail = detail()
        self.emptyState = emptyState()
    }

    public var body: some View {
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
        .environment(\.panelKeyboardNavigation, navigation)
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
        if let offset = PanelKeyboardNavigation.offset(
            for: press.key, modifiers: press.modifiers,
            pageSize: actions.isShowing ? navigation.actionsPageSize : navigation.resultsPageSize
        ) {
            if actions.isShowing { actions.moveSelection(by: offset) } else { onMove(offset) }
            navigation.moved(in: actions.isShowing ? .actions : .results)
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
}
