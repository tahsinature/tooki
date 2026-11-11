import AppKit

/// One launcher result: an app, a command, a menu bar item or a calculation.
struct SearchItem: Identifiable {
    /// Results are listed under these headings, in this order, before you type.
    enum Group: String, CaseIterable {
        case calculator = "Calculator"
        case applications = "Applications"
        case commands = "Commands"
        case menuBar = "Menu Bar Items"
    }

    /// The big answer card shown above the results, like Raycast's calculator.
    struct Calculation {
        let expression: String
        let result: String
        /// Describes the answer under it, e.g. "Number" or "Currency".
        let resultLabel: String
    }

    let id: String
    let title: String
    var subtitle: String?
    var keyword: String?
    /// The quiet label at the end of the row, e.g. "Application".
    let kind: String
    let group: Group
    let icon: PanelIcon
    /// Extra text matched by the search.
    var searchText = ""
    var calculation: Calculation?
    /// What ↵ does, shown in the bottom bar.
    let actionTitle: String
    /// More entries for the ⌘K popup, after the main action and Copy.
    var extraActions: [SearchAction] = []
    /// Copies the item with ⌘↵. `nil` when the item cannot be copied.
    var copy: (@MainActor () -> Void)?
    let run: @MainActor () -> Void
}

/// An entry in the launcher's ⌘K popup.
struct SearchAction: PanelActionItem {
    let id: String
    let title: String
    let icon: PanelIcon
    var shortcut = ""
    var isDestructive = false
    let run: @MainActor () -> Void
}
