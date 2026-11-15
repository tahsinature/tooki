import ComposableArchitecture
import Foundation

public enum ShelfDestructiveAction: Equatable, Sendable { case clear, delete }

/// Selection and presentation state for a floating shelf. File ownership stays in the native app.
@Reducer
public struct ShelfFeature {
    @ObservableState
    public struct State: Equatable {
        public var itemIDs: [UUID]
        public var selection: Set<UUID> = []
        public var cursor: UUID?
        public var isExpanded = false
        public var isShowingDetail = false
        public var armed: ShelfDestructiveAction?
        public init(itemIDs: [UUID] = []) { self.itemIDs = itemIDs }
    }

    public enum Action: Equatable {
        case itemsChanged([UUID])
        case selectionChanged(Set<UUID>)
        case clicked(UUID, extending: Bool)
        case showDetail(UUID)
        case moveSelection(Int, extending: Bool)
        case expanded(Bool)
        case detailPresented(Bool)
        case arm(ShelfDestructiveAction)
        case disarm
    }

    @Dependency(\.continuousClock) var clock
    private enum CancelID { case disarm }
    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .itemsChanged(ids):
                state.itemIDs = ids
                state.selection.formIntersection(ids)
                if let cursor = state.cursor, !ids.contains(cursor) { state.cursor = nil }
                if ids.isEmpty {
                    state.isExpanded = false
                    state.isShowingDetail = false
                }
            case let .selectionChanged(ids): state.selection = ids.intersection(state.itemIDs)
            case let .clicked(id, extending):
                guard state.itemIDs.contains(id) else { return .none }
                state.cursor = id
                if extending {
                    if state.selection.remove(id) == nil { state.selection.insert(id) }
                } else { state.selection = [id] }
            case let .showDetail(id):
                guard state.itemIDs.contains(id) else { return .none }
                state.cursor = id
                state.selection = [id]
                state.isShowingDetail = true
            case let .moveSelection(offset, extending):
                guard !state.itemIDs.isEmpty else { return .none }
                let next: Int
                if let current = state.cursor.flatMap({ state.itemIDs.firstIndex(of: $0) }), !state.selection.isEmpty {
                    next = current + min(max(offset, -current), state.itemIDs.count - 1 - current)
                } else { next = offset > 0 ? 0 : state.itemIDs.count - 1 }
                let id = state.itemIDs[next]
                state.cursor = id
                if extending { state.selection.insert(id) } else { state.selection = [id] }
            case let .expanded(expanded):
                state.isExpanded = expanded
                if !expanded { state.isShowingDetail = false }
            case let .detailPresented(shown): state.isShowingDetail = shown
            case let .arm(action):
                state.armed = action
                return .run { [clock] send in
                    try await clock.sleep(for: .seconds(4))
                    await send(.disarm)
                }.cancellable(id: CancelID.disarm, cancelInFlight: true)
            case .disarm:
                state.armed = nil
                return .cancel(id: CancelID.disarm)
            }
            return .none
        }
    }
}
