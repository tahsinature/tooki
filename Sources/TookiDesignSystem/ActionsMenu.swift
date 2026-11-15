import Observation

/// State of a panel's ⌘K popup: whether it shows, its filter and selection, and an optional
/// submenu (such as "Open With" or a delete confirmation) that replaces the list until Esc goes back.
@MainActor
@Observable
public final class ActionsMenu<Action: PanelActionItem> {
    public init() {}

    public struct Submenu {
        public let title: String
        public let actions: [Action]
        /// The row to select again when Esc returns to the main list.
        public let parentID: Action.ID?
    }

    public private(set) var isShowing = false
    public private(set) var submenu: Submenu?
    /// Filters the rows. Separate from the panel's search, so typing here never changes the list behind.
    public var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    public var selection = 0

    /// The main list, usually the actions for the selected item. Set by the owning model.
    @ObservationIgnored public var rootActions: () -> [Action] = { [] }

    /// The rows showing right now, filtered by `query`.
    public var visibleActions: [Action] {
        let words = query.lowercased().split(separator: " ")
        return (submenu?.actions ?? rootActions()).filter { action in
            words.allSatisfy { action.title.lowercased().contains($0) }
        }
    }

    public var selectedAction: Action? {
        let actions = visibleActions
        return actions.indices.contains(selection) ? actions[selection] : nil
    }

    public func toggle() {
        isShowing ? close() : open()
    }

    /// Does nothing when there are no actions to list.
    public func open() {
        guard !rootActions().isEmpty else { return }
        submenu = nil
        query = ""
        selection = 0
        isShowing = true
    }

    public func close() {
        isShowing = false
        submenu = nil
        query = ""
        selection = 0
    }

    public func showSubmenu(title: String, actions: [Action], parentID: Action.ID? = nil) {
        isShowing = true
        submenu = Submenu(title: title, actions: actions, parentID: parentID)
        query = ""
        selection = 0
    }

    /// Esc steps back one level: from a submenu to the main list, then closes the popup.
    /// Returns `false` when nothing was open.
    public func dismiss() -> Bool {
        if let submenu {
            self.submenu = nil
            query = ""
            selection = visibleActions.firstIndex { $0.id == submenu.parentID } ?? 0
        } else if isShowing {
            close()
        } else {
            return false
        }
        return true
    }

    public func moveSelection(by offset: Int) {
        selection = max(min(selection + offset, visibleActions.count - 1), 0)
    }
}
