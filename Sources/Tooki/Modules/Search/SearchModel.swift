import AppKit
import Observation
import TookiKit

/// A heading and the results under it.
struct SearchSection: Identifiable {
    let title: String
    let items: [SearchItem]
    var id: String { title }
}

/// State of the launcher: the query, ranked results, the selection and the ⌘K popup.
@MainActor
@Observable
final class SearchModel {
    var query = "" {
        didSet { if query != oldValue { rebuild() } }
    }
    /// Shows only this group. `nil` shows everything.
    var groupFilter: SearchItem.Group? {
        didSet { if groupFilter != oldValue { rebuild() } }
    }
    /// The groups offered in the filter menu. Empty hides the menu.
    let filterGroups: [SearchItem.Group]
    private(set) var sections: [SearchSection] = []
    /// Every listed result, top to bottom, so arrow keys can walk across sections.
    private(set) var results: [SearchItem] = []
    var selection = 0

    var isShowingActions = false {
        didSet {
            guard isShowingActions != oldValue else { return }
            menuQuery = ""
            actionSelection = 0
        }
    }
    var menuQuery = "" {
        didSet { if menuQuery != oldValue { actionSelection = 0 } }
    }
    var actionSelection = 0

    let placeholder: String
    let title: String
    let icon: PanelIcon
    private var items: [SearchItem]
    private var history: LaunchHistory
    private let calculate: (String) -> SearchItem?

    init(
        items: [SearchItem],
        placeholder: String,
        title: String,
        icon: PanelIcon,
        filterGroups: [SearchItem.Group] = [],
        history: LaunchHistory,
        calculate: @escaping (String) -> SearchItem? = { _ in nil }
    ) {
        self.items = items
        self.placeholder = placeholder
        self.title = title
        self.icon = icon
        self.filterGroups = filterGroups
        self.history = history
        self.calculate = calculate
        rebuild()
    }

    /// Refresh dynamic entries without resetting the query, filter, menu or selected identity.
    func refresh(items: [SearchItem], history: LaunchHistory) {
        let selectedID = selectedItem?.id
        self.items = items
        self.history = history
        updateResults()
        selection = results.firstIndex { $0.id == selectedID } ?? 0
    }

    var selectedItem: SearchItem? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + offset, 0), results.count - 1)
    }

    // MARK: Actions popup

    var menuActions: [SearchAction] {
        guard let item = selectedItem else { return [] }
        var actions = [SearchAction(id: "run", title: item.actionTitle, icon: item.icon, shortcut: "↵", run: item.run)]
        if let copy = item.copy {
            actions.append(SearchAction(id: "copy", title: "Copy", icon: .symbol("doc.on.doc"), shortcut: "⌘↵", run: copy))
        }
        actions += item.extraActions
        let words = menuQuery.lowercased().split(separator: " ")
        return actions.filter { action in words.allSatisfy { action.title.lowercased().contains($0) } }
    }

    var selectedMenuAction: SearchAction? {
        let actions = menuActions
        return actions.indices.contains(actionSelection) ? actions[actionSelection] : nil
    }

    func moveActionSelection(by offset: Int) {
        actionSelection = max(min(actionSelection + offset, menuActions.count - 1), 0)
    }

    // MARK: Ranking

    private func rebuild() {
        selection = 0
        isShowingActions = false
        updateResults()
    }

    private func updateResults() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        sections = trimmed.isEmpty ? browsingSections() : searchSections(for: trimmed)
        results = sections.flatMap(\.items)
    }

    private var filteredItems: [SearchItem] {
        guard let groupFilter else { return items }
        return items.filter { $0.group == groupFilter }
    }

    /// Before you type: your most-used results first, then everything by group.
    private func browsingSections() -> [SearchSection] {
        let items = filteredItems
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let recent = history.recentIDs(limit: 5).compactMap { byID[$0] }
        let recentIDs = Set(recent.map(\.id))
        let rest = items.filter { !recentIDs.contains($0.id) }
        let grouped = SearchItem.Group.allCases.compactMap { group -> SearchSection? in
            let members = rest.filter { $0.group == group }
            return members.isEmpty ? nil : SearchSection(title: group.rawValue, items: members)
        }
        return (recent.isEmpty ? [] : [SearchSection(title: "Recent", items: recent)]) + grouped
    }

    private func searchSections(for query: String) -> [SearchSection] {
        let ranked = filteredItems
            .compactMap { item in score(item, for: query).map { (item, $0 + history.boost(for: item.id)) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        var sections: [SearchSection] = []
        if groupFilter == nil, let calculation = calculate(query) {
            sections.append(SearchSection(title: "Calculator", items: [calculation]))
        }
        if !ranked.isEmpty {
            sections.append(SearchSection(title: "Results", items: ranked))
        }
        return sections
    }

    /// The title counts most; a keyword hit is nearly as good; text elsewhere still finds the item.
    private func score(_ item: SearchItem, for query: String) -> Double? {
        if let titleScore = FuzzyMatch.score(query, in: item.title) { return titleScore }
        if let keyword = item.keyword, keyword.lowercased().hasPrefix(query.lowercased()) { return 85 }
        let haystack = "\(item.subtitle ?? "") \(item.kind) \(item.searchText)".lowercased()
        let words = query.lowercased().split(separator: " ")
        return words.allSatisfy { haystack.contains($0) } ? 10 : nil
    }
}
