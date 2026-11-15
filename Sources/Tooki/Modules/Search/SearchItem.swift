import TookiDesignSystem
import AppKit
import SearchFeature

/// One launcher result: an app, a command, a menu bar item or a calculation.
struct SearchItem: Identifiable {
    /// Results are listed under these headings, in this order, before you type.
    typealias Group = SearchGroup

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

    @MainActor var actions: [SearchAction] {
        var result = [SearchAction(id: "run", title: actionTitle, icon: icon, shortcut: "↵", run: run)]
        if let copy { result.append(SearchAction(id: "copy", title: "Copy", icon: .symbol("doc.on.doc"), shortcut: "⌘↵", run: copy)) }
        return result + extraActions
    }

    @MainActor var metadata: SearchEntry {
        SearchEntry(id: id, title: title, subtitle: subtitle, keyword: keyword, kind: kind, group: group,
                    searchText: searchText, actions: actions.map { SearchActionMetadata(id: $0.id, title: $0.title) })
    }
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
