import AppKit
import Observation
import TookiKit

/// State of the clipboard panel: search, type filter, selection and the ⌘K menu.
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
    let actions = ActionsMenu<ClipboardAction>()

    let history: ClipboardHistory
    /// The app that was in front when the panel opened; pasting goes there.
    var targetAppName: String?

    init(history: ClipboardHistory, targetAppName: String?) {
        self.history = history
        self.targetAppName = targetAppName
        actions.rootActions = { [weak self] in
            guard let self, let item = selectedItem else { return [] }
            return ClipboardAction.all(for: item, targetAppName: self.targetAppName)
        }
    }

    var pinned: [ClipboardItem] { results.filter(\.isPinned) }
    var recent: [ClipboardItem] { results.filter { !$0.isPinned } }

    /// Items in the order they are shown: pinned first.
    var orderedResults: [ClipboardItem] { pinned + recent }

    var itemCountLabel: String {
        let total = history.items.count.formatted()
        let isFiltering = typeFilter != nil || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isFiltering ? "\(results.count.formatted()) of \(total)" : total
    }

    var selectedItem: ClipboardItem? {
        let ordered = orderedResults
        return ordered.first { $0.id == selectedID } ?? ordered.first
    }

    func showOpenWith() {
        guard let item = selectedItem, item.canBeUsed, ClipboardOpenWith.canOpen(item) else { return }
        actions.showSubmenu(title: "Open With", actions: ClipboardOpenWith.actions(for: item), parentID: .openWith)
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
