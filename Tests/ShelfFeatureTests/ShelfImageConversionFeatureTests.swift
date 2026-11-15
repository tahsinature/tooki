import ComposableArchitecture
import Foundation
import Testing
import TookiKit
@testable import ShelfFeature

@MainActor
struct ShelfImageConversionFeatureTests {
    private enum Failure: Error { case expected }

    private func client(_ fixtures: [ConversionFixture]) -> ShelfConversionClient {
        ShelfConversionClient(
            validate: { _ in },
            prepare: { item, _ in try #require(fixtures.first { $0.item.id == item.id }).result.preview },
            details: { preview in try #require(fixtures.first { $0.result.preview == preview }).result.details },
            save: { result, _ in result.item.id },
            discard: { _ in }, didSave: { _ in }, dismissPreview: {}, close: {}
        )
    }

    private func store(_ state: ShelfImageConversionFeature.State, client: ShelfConversionClient)
        -> TestStore<ShelfImageConversionFeature.State, ShelfImageConversionFeature.Action> {
        let store = TestStore(initialState: state) { ShelfImageConversionFeature() } withDependencies: {
            $0.shelfConversionClient = client
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    @Test func prepareBatchReportsFailuresAndSaveKeepsOnlyFailedInputsForRetry() async throws {
        let good = try ConversionFixture()
        let bad = try ConversionFixture(name: "bad.png")
        defer { good.cleanUp(); bad.cleanUp() }
        let discarded = LockIsolated<[URL]>([])
        let saved = LockIsolated<[UUID]>([])
        let outputs = LockIsolated<[ImageConversionOptions.Output]>([])
        var service = client([good, bad])
        service.prepare = { item, _ in
            if item.id == bad.item.id { throw Failure.expected }
            return good.result.preview
        }
        service.discard = { preview in discarded.withValue { $0.append(preview.url) } }
        service.didSave = { rows in saved.setValue(rows) }
        service.save = { result, output in
            outputs.withValue { $0.append(output) }
            return result.item.id
        }
        let store = store(.init(items: [good.item, bad.item]), client: service)
        await store.send(.convert)
        await store.receive(\.preparationFinished)
        #expect(store.state.phase == .review)
        #expect(store.state.completed == 2)
        #expect(store.state.results.count == 1)
        #expect(store.state.errors.first?.hasPrefix("bad.png:") == true)
        await store.send(.save(.copy))
        await store.receive(\.saveFinished)
        await store.finish()
        #expect(store.state.phase == .settings)
        #expect(store.state.items == [bad.item])
        #expect(saved.value == [good.item.id])
        #expect(outputs.value == [.copy])
        #expect(discarded.value == [good.result.preview.url])
        #expect(!store.state.isClosed)
    }

    @Test func savingIsNonCancellableAndPartialFailureRemainsReviewable() async throws {
        let first = try ConversionFixture()
        let second = try ConversionFixture(name: "second.png")
        defer { first.cleanUp(); second.cleanUp() }
        let started = AsyncStream<Void>.makeStream()
        let gate = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
        var service = client([first, second])
        service.save = { result, _ in
            if result.item.id == first.item.id {
                await withCheckedContinuation { continuation in
                    gate.setValue(continuation)
                    started.continuation.yield(())
                }
                return first.item.id
            }
            throw Failure.expected
        }
        var state = ShelfImageConversionFeature.State(items: [first.item, second.item])
        state.phase = .review
        state.results = [first.result, second.result]
        let store = store(state, client: service)
        await store.send(.save(.replace))
        var iterator = started.stream.makeAsyncIterator()
        await iterator.next()
        await store.send(.discard)
        await store.send(.back)
        #expect(store.state.phase == .saving)
        #expect(!store.state.isClosed)
        gate.value?.resume()
        await store.receive(\.saveFinished)
        await store.finish()
        #expect(store.state.phase == .review)
        #expect(store.state.items == [second.item])
        #expect(store.state.results.map(\.item.id) == [second.item.id])
        #expect(store.state.errors.first?.hasPrefix("second.png:") == true)
    }

    @Test func cancellationDiscardsPreviewThatFinishesAfterClosing() async throws {
        let fixture = try ConversionFixture()
        defer { fixture.cleanUp() }
        let started = AsyncStream<Void>.makeStream()
        let discarded = AsyncStream<URL>.makeStream()
        let gate = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
        let closed = LockIsolated(false)
        var service = client([fixture])
        service.prepare = { _, _ in
            await withCheckedContinuation { continuation in
                gate.setValue(continuation)
                started.continuation.yield(())
            }
            return fixture.result.preview
        }
        service.discard = { preview in discarded.continuation.yield(preview.url) }
        service.close = { closed.setValue(true) }
        let store = store(.init(items: [fixture.item]), client: service)
        await store.send(.convert)
        var startedIterator = started.stream.makeAsyncIterator()
        await startedIterator.next()
        await store.send(.discard)
        #expect(store.state.isClosed)
        gate.value?.resume()
        var discardedIterator = discarded.stream.makeAsyncIterator()
        let url = await discardedIterator.next()
        await store.finish()
        #expect(url == fixture.result.preview.url)
        #expect(store.state.results.isEmpty)
        #expect(closed.value)
    }

    @Test func refreshBlocksInvalidPreviewsAndAllowsSavingAfterRecovery() async throws {
        let fixture = try ConversionFixture()
        defer { fixture.cleanUp() }
        let fails = LockIsolated(true)
        var service = client([fixture])
        service.details = { _ in
            if fails.value { throw Failure.expected }
            return fixture.result.details
        }
        var state = ShelfImageConversionFeature.State(items: [fixture.item])
        state.phase = .review
        state.results = [fixture.result]
        let store = store(state, client: service)
        await store.send(.refresh)
        await store.receive(\.refreshFinished)
        #expect(!store.state.canSave)
        await store.send(.save(.replace))
        #expect(store.state.phase == .review)
        fails.setValue(false)
        await store.send(.refresh)
        await store.receive(\.refreshFinished)
        #expect(store.state.canSave)
        await store.send(.moveReview(Int.max))
        await store.send(.moveReview(Int.min))
        #expect(store.state.reviewIndex == 0)
        await store.finish()
    }

    @Test func backPreservesFilesOpenedExternallyAndIgnoresStaleRefreshResponses() async throws {
        let first = try ConversionFixture()
        let second = try ConversionFixture(name: "second.png")
        defer { first.cleanUp(); second.cleanUp() }
        let discarded = LockIsolated<[URL]>([])
        var service = client([first, second])
        service.discard = { preview in discarded.withValue { $0.append(preview.url) } }
        var state = ShelfImageConversionFeature.State(items: [first.item, second.item])
        state.phase = .review
        state.results = [first.result, second.result]
        let oldRefresh = UUID()
        state.refreshID = oldRefresh
        let store = store(state, client: service)
        await store.send(.markOpened([first.result.id]))
        await store.send(.moveReview(Int.max))
        #expect(store.state.reviewIndex == 1)
        await store.send(.back)
        await store.send(.detailsLoaded(refresh: oldRefresh, result: first.result.id, first.result.details))
        await store.finish()
        #expect(store.state.phase == .settings)
        #expect(store.state.results.isEmpty)
        #expect(discarded.value == [second.result.preview.url])
    }

    @Test func successfulSaveClosesOnceAndValidationFailureReturnsToSettings() async throws {
        let fixture = try ConversionFixture()
        defer { fixture.cleanUp() }
        let closes = LockIsolated(0)
        var service = client([fixture])
        service.close = { closes.withValue { $0 += 1 } }
        var state = ShelfImageConversionFeature.State(items: [fixture.item])
        state.phase = .review
        state.results = [fixture.result]
        let successful = store(state, client: service)
        await successful.send(.save(.replace))
        await successful.receive(\.saveFinished)
        await successful.finish()
        await successful.send(.discard)
        #expect(successful.state.isClosed)
        #expect(closes.value == 1)

        service.validate = { _ in throw Failure.expected }
        let invalid = store(.init(items: [fixture.item]), client: service)
        await invalid.send(.convert)
        await invalid.receive(\.validationFailed)
        #expect(invalid.state.phase == .settings)
        #expect(invalid.state.completed == 0)
        #expect(invalid.state.errors.count == 1)
        await invalid.finish()
    }
}
