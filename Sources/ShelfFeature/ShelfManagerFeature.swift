import ComposableArchitecture
import Foundation

public struct ShelfSummary: Equatable, Sendable, Identifiable {
    public struct Item: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }
    }
    public let id: UUID
    public let name: String
    public let lastUsed: Date
    public let items: [Item]
    public init(id: UUID, name: String, lastUsed: Date, items: [Item]) {
        self.id = id
        self.name = name
        self.lastUsed = lastUsed
        self.items = items
    }
}

/// Shelf manager browsing and rename state, independent of native windows and file operations.
@Reducer
public struct ShelfManagerFeature {
    @ObservableState
    public struct State: Equatable {
        public var shelves: [ShelfSummary]
        public var query = ""
        public var renamingShelfID: UUID?
        public var openShelfID: UUID?
        public var selectedShelfID: UUID?
        public var selectedItemID: UUID?
        public var isShowingConversion = false
        public init(shelves: [ShelfSummary]) { self.shelves = shelves }

        public var visibleShelves: [ShelfSummary] {
            shelves.filter { shelf in
                renamingShelfID != nil || query.isEmpty || matches(shelf.name) || shelf.items.contains { matches($0.name) }
            }.sorted { $0.lastUsed > $1.lastUsed }
        }
        public var visibleItems: [ShelfSummary.Item] {
            (shelves.first { $0.id == openShelfID }?.items ?? []).filter { query.isEmpty || matches($0.name) }
        }
        public var selectedShelf: ShelfSummary? { visibleShelves.first { $0.id == selectedShelfID } ?? visibleShelves.first }
        public var selectedItem: ShelfSummary.Item? { visibleItems.first { $0.id == selectedItemID } ?? visibleItems.first }
        private func matches(_ text: String) -> Bool {
            text.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespaces))
        }
    }

    public enum Action: Equatable {
        case refreshed([ShelfSummary])
        case queryChanged(String)
        case shelfSelected(UUID?)
        case itemSelected(UUID?)
        case open(UUID)
        case select(UUID)
        case closeShelf
        case startRenaming(UUID)
        case finishRenaming
        case conversionPresented(Bool)
        case moveSelection(Int)
        case resetPosition
    }
    public init() {}
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .refreshed(shelves):
                state.shelves = shelves
                if let id = state.openShelfID, !shelves.contains(where: { $0.id == id }) { state.openShelfID = nil }
                if let id = state.renamingShelfID, !shelves.contains(where: { $0.id == id }) {
                    state.renamingShelfID = nil
                    state.query = ""
                }
            case let .queryChanged(query):
                guard query != state.query else { return .none }
                state.query = query
                if state.renamingShelfID == nil {
                    state.selectedShelfID = nil
                    state.selectedItemID = nil
                }
            case let .shelfSelected(id): state.selectedShelfID = id
            case let .itemSelected(id): state.selectedItemID = id
            case let .open(id):
                state.query = ""
                state.openShelfID = id
                state.selectedShelfID = id
                state.selectedItemID = nil
            case let .select(id):
                state.openShelfID = nil
                state.query = ""
                state.selectedShelfID = id
            case .closeShelf:
                state.selectedShelfID = state.openShelfID
                state.openShelfID = nil
                state.query = ""
            case let .startRenaming(id):
                guard let shelf = state.shelves.first(where: { $0.id == id }) else { return .none }
                state.renamingShelfID = id
                state.selectedShelfID = id
                state.query = shelf.name
            case .finishRenaming:
                state.selectedShelfID = state.renamingShelfID
                state.renamingShelfID = nil
                state.query = ""
            case let .conversionPresented(shown): state.isShowingConversion = shown
            case let .moveSelection(offset):
                guard state.renamingShelfID == nil, !state.isShowingConversion else { return .none }
                if state.openShelfID != nil {
                    state.selectedItemID = Self.neighbour(state.selectedItem?.id, in: state.visibleItems.map(\.id), offset: offset)
                } else {
                    state.selectedShelfID = Self.neighbour(state.selectedShelf?.id, in: state.visibleShelves.map(\.id), offset: offset)
                }
            case .resetPosition:
                if state.openShelfID != nil { state.selectedItemID = state.visibleItems.first?.id }
                else { state.selectedShelfID = state.visibleShelves.first?.id }
            }
            return .none
        }
    }
    private static func neighbour(_ current: UUID?, in ids: [UUID], offset: Int) -> UUID? {
        guard !ids.isEmpty else { return nil }
        let index = ids.firstIndex { $0 == current } ?? 0
        return ids[index + min(max(offset, -index), ids.count - 1 - index)]
    }
}
