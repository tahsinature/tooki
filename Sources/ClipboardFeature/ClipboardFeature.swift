import ComposableArchitecture
import Foundation
import TookiKit

/// Clipboard's state and actions are independent of native windows and panel rendering.
@Reducer
public struct ClipboardFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var items: [ClipboardItem]
        public var query = ""
        public var typeFilter: ClipboardContentType?
        public var selectedID: ClipboardItem.ID?
        public internal(set) var orderedResults: [ClipboardItem] = []
        public internal(set) var pinnedCount = 0
        var sourceNames: [String: String]

        public init(items: [ClipboardItem] = [], sourceNames: [String: String] = [:]) {
            self.items = items
            self.sourceNames = sourceNames
            rebuildResults()
        }

        public var selectedItem: ClipboardItem? {
            orderedResults.first { $0.id == selectedID } ?? orderedResults.first
        }

        public var itemCountLabel: String {
            let total = items.count.formatted()
            let isFiltering = typeFilter != nil || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return isFiltering ? "\(orderedResults.count.formatted()) of \(total)" : total
        }
    }

    public enum Action: Equatable, Sendable {
        case queryChanged(String)
        case typeFilterChanged(ClipboardContentType?)
        case selectionChanged(ClipboardItem.ID?)
        case moveSelection(Int)
        case resetPosition
        case historyChanged([ClipboardItem], sourceNames: [String: String])
        case togglePin
        case deleteSelected
        case copySelected
        case pasteSelected
    }

    @Dependency(\.clipboardClient) var clipboard
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .queryChanged(let query):
                guard state.query != query else { return .none }
                state.query = query
                state.selectedID = nil
                state.rebuildResults()
            case .typeFilterChanged(let filter):
                guard state.typeFilter != filter else { return .none }
                state.typeFilter = filter
                state.selectedID = nil
                state.rebuildResults()
            case .selectionChanged(let id):
                state.selectedID = id
            case .moveSelection(let offset):
                guard !state.orderedResults.isEmpty else { return .none }
                let selectedID = state.selectedID
                let current = state.orderedResults.firstIndex { $0.id == selectedID } ?? 0
                // Saturate before adding so even a very large keyboard offset cannot overflow.
                let bounded = max(-state.orderedResults.count, min(offset, state.orderedResults.count))
                let next = min(max(current + bounded, 0), state.orderedResults.count - 1)
                state.selectedID = state.orderedResults[next].id
            case .resetPosition:
                state.selectedID = state.orderedResults.first?.id
            case let .historyChanged(items, sourceNames):
                state.items = items
                state.sourceNames = sourceNames
                state.rebuildResults()
            case .togglePin:
                guard let item = state.selectedItem,
                      let index = state.items.firstIndex(where: { $0.id == item.id }) else { return .none }
                state.items[index].isPinned.toggle()
                state.selectedID = item.id
                state.rebuildResults()
                return .run { [clipboard] _ in await clipboard.togglePin(item) }
            case .deleteSelected:
                guard let item = state.selectedItem else { return .none }
                let index = state.orderedResults.firstIndex { $0.id == item.id } ?? 0
                let next = state.orderedResults.dropFirst(index + 1).first
                    ?? state.orderedResults.prefix(index).last
                state.items.removeAll { $0.id == item.id }
                state.selectedID = next?.id
                state.rebuildResults()
                return .run { [clipboard] _ in await clipboard.remove(item) }
            case .copySelected:
                guard let item = state.selectedItem else { return .none }
                return .run { [clipboard] _ in await clipboard.copy(item) }
            case .pasteSelected:
                guard let item = state.selectedItem else { return .none }
                return .run { [clipboard, clock] _ in
                    // Give native focus time to return to the destination app.
                    try await clock.sleep(for: .milliseconds(80))
                    await clipboard.paste(item)
                }
            }
            return .none
        }
    }
}

extension ClipboardFeature.State {
    /// Compute once per data/filter change rather than repeatedly during view rendering.
    mutating func rebuildResults() {
        let words = query.lowercased().split(separator: " ")
        var pinned: [ClipboardItem] = []
        var recent: [ClipboardItem] = []
        for item in items {
            if let typeFilter, item.contentType != typeFilter { continue }
            if !words.isEmpty {
                let text = [item.text, item.image?.recognizedText ?? "", item.files?.joined(separator: " ") ?? "",
                            item.sourceApp.flatMap { sourceNames[$0] } ?? ""].joined(separator: " ").lowercased()
                guard words.allSatisfy({ text.contains($0) }) else { continue }
            }
            if item.isPinned { pinned.append(item) } else { recent.append(item) }
        }
        pinnedCount = pinned.count
        orderedResults = pinned + recent
    }
}
