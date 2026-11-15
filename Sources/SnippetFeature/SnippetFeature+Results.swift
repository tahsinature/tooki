import Foundation
import TookiKit

extension SnippetFeature.State {
    /// Rebuilt on data/filter changes; navigation and rendering reuse this order.
    mutating func rebuildResults() {
        let filter = collectionFilter
        let query = query
        let activity = lastUsed
        let sorted = items.filter { (filter == nil || $0.collection == filter) && $0.matches(query) }
            .sorted {
                (activity[$0.id] ?? $0.modifiedAt ?? $0.createdAt ?? .distantPast)
                    > (activity[$1.id] ?? $1.modifiedAt ?? $1.createdAt ?? .distantPast)
            }
        let pinned = sorted.filter(\.isPinned)
        pinnedCount = pinned.count
        orderedResults = pinned + sorted.filter { !$0.isPinned }
        collections = Set(items.map(\.collection).filter { !$0.isEmpty }).sorted()
    }

    mutating func saveDraft(at now: Date) {
        guard canSaveDraft, var draft = form?.draft else { return }
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.collection = draft.collection.trimmingCharacters(in: .whitespaces)
        draft.modifiedAt = now
        draft.createdAt = draft.createdAt ?? now
        if let index = items.firstIndex(where: { $0.id == draft.id }) {
            items[index] = draft
        } else {
            items.append(draft)
        }
        form = nil
        if (collectionFilter != nil && draft.collection != collectionFilter) || !draft.matches(query) {
            query = ""
            collectionFilter = nil
        }
        selectedID = draft.id
        rebuildResults()
    }
}
