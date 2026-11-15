import Foundation
import TookiKit

extension SearchFeature.State {
    mutating func rebuildResults(at now: Date) {
        let filtered = items.filter { groupFilter == nil || $0.group == groupFilter }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        sections = trimmed.isEmpty ? browsingSections(filtered, at: now) : searchSections(filtered, query: trimmed, at: now)
        results = sections.flatMap(\.items)
        rebuildActions()
    }

    private func browsingSections(_ items: [SearchEntry], at now: Date) -> [SearchSectionState] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let recent = history.recentIDs(limit: 5, now: now).compactMap { byID[$0] }
        let recentIDs = Set(recent.map(\.id))
        let rest = items.filter { !recentIDs.contains($0.id) }
        let groups = SearchGroup.allCases.compactMap { group -> SearchSectionState? in
            let members = rest.filter { $0.group == group }
            return members.isEmpty ? nil : SearchSectionState(title: group.rawValue, items: members)
        }
        return (recent.isEmpty ? [] : [SearchSectionState(title: "Recent", items: recent)]) + groups
    }

    private func searchSections(_ items: [SearchEntry], query: String, at now: Date) -> [SearchSectionState] {
        let ranked = items.compactMap { item in
            score(item, for: query).map { (item, $0 + history.boost(for: item.id, now: now)) }
        }.sorted { $0.1 > $1.1 }.map(\.0)
        var sections: [SearchSectionState] = []
        if groupFilter == nil, let calculation {
            sections.append(SearchSectionState(title: "Calculator", items: [calculation]))
        }
        if !ranked.isEmpty { sections.append(SearchSectionState(title: "Results", items: ranked)) }
        return sections
    }

    private func score(_ item: SearchEntry, for query: String) -> Double? {
        if let score = FuzzyMatch.score(query, in: item.title) { return score }
        if let keyword = item.keyword, keyword.lowercased().hasPrefix(query.lowercased()) { return 85 }
        let haystack = "\(item.subtitle ?? "") \(item.kind) \(item.searchText)".lowercased()
        let words = query.lowercased().split(separator: " ")
        return words.allSatisfy { haystack.contains($0) } ? 10 : nil
    }
}
