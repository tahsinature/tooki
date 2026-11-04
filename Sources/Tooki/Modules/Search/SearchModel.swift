import AppKit
import Observation

struct SearchItem: Identifiable {
    let id: String
    let title: String
    var keyword: String?
    let kind: String
    let icon: String
    /// Extra text matched by the search, e.g. the snippet body.
    var searchText = ""
    /// Shown as a thumbnail and a larger preview.
    var imageURL: URL?
    /// Shown instead of the `icon` symbol, e.g. the app that owns a menu bar item.
    var appIcon: NSImage?
    /// Copies the item with ⌘↵. `nil` when the item cannot be copied.
    var copy: (@MainActor () -> Void)?
    let run: @MainActor () -> Void
}

@MainActor
@Observable
final class SearchModel {
    var query = "" {
        didSet { selection = 0 }
    }
    var selection = 0

    let placeholder: String
    /// Keyboard help shown in the footer.
    let hint: String
    private let items: [SearchItem]

    init(items: [SearchItem], placeholder: String, hint: String) {
        self.items = items
        self.placeholder = placeholder
        self.hint = hint
    }

    var results: [SearchItem] {
        let words = query.lowercased().split(separator: " ")
        guard !words.isEmpty else { return items }
        return items.filter { item in
            let haystack = "\(item.title) \(item.keyword ?? "") \(item.kind) \(item.searchText)".lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    var selectedItem: SearchItem? {
        let results = results
        return results.indices.contains(selection) ? results[selection] : nil
    }

    func moveSelection(by offset: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = min(max(selection + offset, 0), count - 1)
    }
}
