import AppKit
import Observation
import TookiKit

/// State of the clipboard panel: search, type filter, selection and the actions menu.
@MainActor
@Observable
final class ClipboardPanelModel {
    // Text fields write their value back when they lose focus, so only a real change resets the selection.
    var query = "" {
        didSet { if query != oldValue { selectedID = nil } }
    }
    /// `nil` shows all types.
    var typeFilter: ClipboardContentType? {
        didSet { if typeFilter != oldValue { selectedID = nil } }
    }
    var selectedID: ClipboardItem.ID?
    var isShowingActions = false {
        didSet { if !isShowingActions { openWithActions = nil } }
    }
    /// The apps listed while the actions menu shows "Open With…".
    var openWithActions: [ClipboardAction]? {
        didSet { menuQuery = "" }
    }
    /// Filters the actions menu. Separate from `query`, so typing in the menu never changes the list.
    var menuQuery = "" {
        didSet { actionSelection = 0 }
    }
    var actionSelection = 0

    let history: ClipboardHistory
    /// The app that was in front when the panel opened; pasting goes there.
    let targetAppName: String?

    init(history: ClipboardHistory, targetAppName: String?) {
        self.history = history
        self.targetAppName = targetAppName
    }

    var pinned: [ClipboardItem] { results.filter(\.isPinned) }
    var recent: [ClipboardItem] { results.filter { !$0.isPinned } }

    /// Items in the order they are shown: pinned first.
    var orderedResults: [ClipboardItem] { pinned + recent }

    var selectedItem: ClipboardItem? {
        let ordered = orderedResults
        return ordered.first { $0.id == selectedID } ?? ordered.first
    }

    /// The rows the actions menu shows right now, filtered by `menuQuery`.
    var menuActions: [ClipboardAction] {
        let words = menuQuery.lowercased().split(separator: " ")
        return unfilteredMenuActions.filter { action in
            words.allSatisfy { action.title.lowercased().contains($0) }
        }
    }

    private var unfilteredMenuActions: [ClipboardAction] {
        if let openWithActions { return openWithActions }
        guard let item = selectedItem else { return [] }
        return ClipboardAction.all(for: item, targetAppName: targetAppName)
    }

    func toggleActions() {
        menuQuery = ""
        isShowingActions.toggle()
    }

    func showOpenWith() {
        guard let item = selectedItem, ClipboardOpenWith.canOpen(item) else { return }
        isShowingActions = true
        openWithActions = ClipboardOpenWith.actions(for: item)
    }

    /// Esc steps back one level: from the app list to the actions, then closes the actions.
    /// Returns `false` when no menu was open.
    func dismissMenu() -> Bool {
        if openWithActions != nil {
            openWithActions = nil
            actionSelection = menuActions.firstIndex { $0.kind == .openWith } ?? 0
        } else if isShowingActions {
            menuQuery = ""
            isShowingActions = false
        } else {
            return false
        }
        return true
    }

    func moveSelection(by offset: Int) {
        let ordered = orderedResults
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.id == selectedItem?.id } ?? 0
        let next = min(max(current + offset, 0), ordered.count - 1)
        selectedID = ordered[next].id
    }

    func togglePinOfSelected() {
        guard let item = selectedItem else { return }
        history.togglePin(item)
        selectedID = item.id
    }

    /// Selects the next item so the keyboard keeps working after a delete.
    func deleteSelected() {
        guard let item = selectedItem else { return }
        let ordered = orderedResults
        let index = ordered.firstIndex { $0.id == item.id } ?? 0
        let neighbour = ordered.indices.contains(index + 1) ? ordered[index + 1] : ordered.dropLast().last
        history.remove(item)
        selectedID = neighbour?.id
    }

    private var results: [ClipboardItem] {
        let words = query.lowercased().split(separator: " ")
        return history.items.filter { item in
            if let typeFilter, item.contentType != typeFilter { return false }
            guard !words.isEmpty else { return true }
            let haystack = searchText(of: item).lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    private func searchText(of item: ClipboardItem) -> String {
        [item.text, item.image?.recognizedText ?? "", item.files?.joined(separator: " ") ?? "", SourceApp.named(item.sourceApp)?.name ?? ""]
            .joined(separator: " ")
    }
}
