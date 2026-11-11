import Observation
import TookiKit

/// State of the emoji picker: search, the grid's sections, the selected emoji and the ⌘K popup.
@MainActor
@Observable
final class EmojiPanelModel {
    struct Section: Identifiable {
        let title: String
        let emoji: [Emoji]
        var id: String { title }
    }

    static let columns = 10
    /// Rows Page Up and Page Down move, about one screenful of the grid.
    static let pageRows = 5

    var query = "" {
        // The search field writes the same text back when it loses focus to the ⌘K popup.
        didSet { if query != oldValue { rebuild() } }
    }
    private(set) var sections: [Section] = []
    private(set) var results: [Emoji] = []
    var selection = 0
    var isShowingActions = false {
        didSet { actionSelection = 0 }
    }
    var actionSelection = 0

    private let recent: [Emoji]

    init(recentCharacters: [String]) {
        recent = recentCharacters.compactMap { character in EmojiCatalog.all.first { $0.character == character } }
        rebuild()
    }

    var selected: Emoji? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + offset, 0), results.count - 1)
    }

    private func rebuild() {
        selection = 0
        isShowingActions = false
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            let groups = EmojiCatalog.groups.map { group in
                Section(title: group, emoji: EmojiCatalog.all.filter { $0.group == group })
            }
            sections = (recent.isEmpty ? [] : [Section(title: "Recently Used", emoji: recent)]) + groups
        } else {
            sections = [Section(title: "Results", emoji: EmojiCatalog.search(query))]
        }
        sections.removeAll { $0.emoji.isEmpty }
        results = sections.flatMap(\.emoji)
    }
}
