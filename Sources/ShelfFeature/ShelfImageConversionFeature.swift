import ComposableArchitecture
import Foundation
import TookiKit

@Reducer
public struct ShelfImageConversionFeature {
    public enum Phase: Equatable, Sendable { case settings, converting, review, saving }

    @ObservableState
    public struct State: Equatable {
        public var items: [ShelfConversionItem]
        public var options = ImageConversionOptions()
        public var phase = Phase.settings
        public var results: [ShelfConversionResult] = []
        public var completed = 0
        public var errors: [String] = []
        public var reviewIndex = 0
        public var isClosed = false
        var preparationErrors: [UUID: String] = [:]
        var refreshID: UUID?

        public init(items: [ShelfConversionItem]) { self.items = items }
        public var canSave: Bool { !isClosed && phase == .review && !results.isEmpty && results.allSatisfy { $0.error == nil } }
        public var current: ShelfConversionResult? { results.indices.contains(reviewIndex) ? results[reviewIndex] : nil }
    }

    public enum Action: Equatable {
        case optionsChanged(ImageConversionOptions)
        case convert
        case validationFailed(String)
        case prepared(ShelfConversionResult)
        case preparationFailed(UUID, String)
        case preparationFinished
        case save(ImageConversionOptions.Output)
        case saved(source: UUID, row: UUID)
        case saveFailed(String)
        case saveFinished(sources: Set<UUID>, rows: [UUID])
        case refresh
        case detailsLoaded(refresh: UUID, result: UUID, ImagePreviewDetails)
        case detailsFailed(refresh: UUID, result: UUID, String)
        case refreshFinished(UUID)
        case markOpened(Set<UUID>)
        case moveReview(Int)
        case back
        case discard
    }

    @Dependency(\.shelfConversionClient) var client
    @Dependency(\.uuid) var uuid
    enum CancelID { case preparation, refresh }
    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            guard !state.isClosed else {
                // A completed native operation can race with cancellation. Its unclaimed file must go.
                if case let .prepared(result) = action { return .run { [client] _ in await client.discard(result.preview) } }
                return .none
            }
            switch action {
            case let .optionsChanged(options):
                if state.phase == .settings { state.options = options }
            case .convert:
                guard state.phase == .settings, !state.items.isEmpty else { return .none }
                state.phase = .converting
                state.completed = 0
                state.errors = []
                state.preparationErrors = [:]
                return prepare(items: state.items, options: state.options)
            case let .validationFailed(message):
                guard state.phase == .converting else { return .none }
                state.errors = [message]
                state.phase = .settings
            case let .prepared(result):
                guard state.phase == .converting else { return .run { [client] _ in await client.discard(result.preview) } }
                state.results.append(result)
                state.completed += 1
            case let .preparationFailed(id, message):
                guard state.phase == .converting else { return .none }
                state.preparationErrors[id] = message
                state.errors.append(message)
                state.completed += 1
            case .preparationFinished:
                guard state.phase == .converting else { return .none }
                state.reviewIndex = 0
                state.phase = state.results.isEmpty ? .settings : .review
            case let .save(output):
                guard state.canSave else { return .none }
                state.phase = .saving
                state.completed = 0
                state.refreshID = nil
                state.errors = state.items.compactMap { state.preparationErrors[$0.id] }
                return .merge(.cancel(id: CancelID.refresh), save(results: state.results, output: output))
            case .saved:
                guard state.phase == .saving else { return .none }
                state.completed += 1
            case let .saveFailed(message):
                guard state.phase == .saving else { return .none }
                state.errors.append(message)
                state.completed += 1
            case let .saveFinished(sources, rows):
                guard state.phase == .saving else { return .none }
                state.results.removeAll { sources.contains($0.item.id) }
                state.items.removeAll { sources.contains($0.id) }
                if state.items.isEmpty {
                    return close(&state, savedRows: rows)
                }
                state.reviewIndex = 0
                state.phase = state.results.isEmpty ? .settings : .review
                return .run { [client] send in
                    await client.didSave(rows)
                    await send(.refresh)
                }
            case .refresh:
                guard state.phase == .review, state.refreshID == nil else { return .none }
                let id = uuid()
                state.refreshID = id
                return refresh(results: state.results, id: id)
            case let .detailsLoaded(refresh, result, details):
                guard state.phase == .review, state.refreshID == refresh,
                      let index = state.results.firstIndex(where: { $0.id == result }) else { return .none }
                if details != state.results[index].details {
                    state.results[index].details = details
                    state.results[index].revision = uuid()
                }
                state.results[index].error = nil
            case let .detailsFailed(refresh, result, message):
                guard state.phase == .review, state.refreshID == refresh,
                      let index = state.results.firstIndex(where: { $0.id == result }) else { return .none }
                state.results[index].error = message
            case let .refreshFinished(id):
                if state.refreshID == id { state.refreshID = nil }
            case let .markOpened(ids):
                for index in state.results.indices where ids.contains(state.results[index].id) { state.results[index].wasOpened = true }
            case let .moveReview(offset):
                guard state.phase == .review else { return .none }
                state.reviewIndex += min(max(offset, -state.reviewIndex), max(0, state.results.count - 1 - state.reviewIndex))
            case .back:
                guard state.phase != .saving else { return .none }
                if state.phase == .review {
                    let discarded = state.results.filter { !$0.wasOpened }
                    state.results = []
                    state.reviewIndex = 0
                    state.refreshID = nil
                    state.phase = .settings
                    state.errors = []
                    return .merge(.cancel(id: CancelID.refresh), .run { [client] _ in
                        await client.dismissPreview()
                        for result in discarded { await client.discard(result.preview) }
                    })
                }
                return close(&state)
            case .discard:
                guard state.phase != .saving else { return .none }
                return close(&state)
            }
            return .none
        }
    }

    private func close(_ state: inout State, savedRows: [UUID]? = nil) -> Effect<Action> {
        let discarded = state.results.filter { !$0.wasOpened }
        state.isClosed = true
        state.results = []
        state.reviewIndex = 0
        state.refreshID = nil
        return .merge(.cancel(id: CancelID.preparation), .cancel(id: CancelID.refresh), .run { [client] _ in
            if let savedRows { await client.didSave(savedRows) }
            await client.dismissPreview()
            for result in discarded { await client.discard(result.preview) }
            await client.close()
        })
    }
}
