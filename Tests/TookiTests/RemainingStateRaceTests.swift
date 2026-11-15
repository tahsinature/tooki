import AppKit
import ComposableArchitecture
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func detectiveKeepsRapidSameKeyPressesAndSessionsSeparate() async throws {
        let clock = TestClock()
        let delivery = FakeShortcutDelivery()
        let model = ShortcutDetective(deliveryTap: delivery, sleep: { try await clock.sleep(for: $0) })
        #expect(model.start(catalog: ShortcutCatalog(entries: [])))
        defer { model.stop() }
        let first = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 40, keyDown: true))
        first.flags = .maskCommand
        first.timestamp = 100
        let second = try #require(first.copy())
        second.flags = [.maskCommand, .maskShift]
        second.timestamp = 200
        #expect(!model.handle(first, type: .keyDown))
        delivery.callback?(40, 100, getpid())
        #expect(!model.handle(second, type: .keyDown))
        delivery.callback?(40, 200, getpid())
        await clock.advance(by: .milliseconds(250))
        #expect(model.checks.count == 2)
        #expect(Set(model.checks.map(\.combo)).count == 2)
        let oldCallback = delivery.callback
        #expect(!model.handle(first, type: .keyDown))
        model.stop()
        #expect(model.start(catalog: ShortcutCatalog(entries: [])))
        oldCallback?(40, 100, getpid())
        await clock.advance(by: .seconds(1))
        #expect(model.checks.count == 2)
        #expect(!model.handle(first, type: .keyDown))
        oldCallback?(40, 100, getpid())
        await clock.advance(by: .milliseconds(250))
        #expect(model.checks.count == 3)
        if case .takenByUnknown = model.checks[0].verdict {} else {
            Issue.record("A callback from the old listening session was attributed to the new press")
        }
    }

    @Test func layoutRejectsOlderSnapshotsAndPreservesEditsMadeDuringLoad() async {
        let model = MenuBarLayoutEditorModel()
        let gate = SnapshotGate()
        let first = Task {
            await model.load(saved: nil, hasAlwaysHiddenSection: false, capture: { await gate.wait() })
        }
        await gate.started()
        await model.load(saved: nil, hasAlwaysHiddenSection: false, capture: { layoutSnapshot("new") })
        gate.resume(layoutSnapshot("old"))
        await first.value
        #expect(model.shown.map(\.id) == ["new"])

        let editGate = SnapshotGate()
        let reload = Task {
            await model.load(saved: nil, hasAlwaysHiddenSection: false, fromMenuBar: true, capture: { await editGate.wait() })
        }
        await editGate.started()
        let row = model.shown[0]
        model.move(row, to: .hidden)
        editGate.resume(layoutSnapshot("replacement"))
        await reload.value
        #expect(model.hidden.map(\.id) == ["new"])
        #expect(model.isDirty)
        await model.load(saved: nil, hasAlwaysHiddenSection: false, capture: { Issue.record("Implicit reload discarded a dirty draft"); return layoutSnapshot("wrong") })
        #expect(model.hidden.map(\.id) == ["new"])
        model.markSaved()
        #expect(!model.isDirty)
    }

    @Test func cancelledLayoutLoadAndSavedDraftRejectPendingSnapshots() async {
        let model = MenuBarLayoutEditorModel()
        let gate = SnapshotGate()
        let cancelled = Task {
            await model.load(saved: nil, hasAlwaysHiddenSection: false, capture: { await gate.wait() })
        }
        await gate.started()
        cancelled.cancel()
        gate.resume(layoutSnapshot("cancelled"))
        await cancelled.value
        #expect(model.shown.isEmpty)
        let savedGate = SnapshotGate()
        let pending = Task {
            await model.load(saved: nil, hasAlwaysHiddenSection: false, capture: { await savedGate.wait() })
        }
        await savedGate.started()
        model.markSaved()
        savedGate.resume(layoutSnapshot("before-save"))
        await pending.value
        #expect(model.shown.isEmpty)
    }

    @Test func keepAwakeAdapterShutsDownWithoutRetainingNativeObservers() {
        var model: KeepAwake? = KeepAwake()
        weak var released = model
        #expect(model?.isActive == false)
        model?.shutdown()
        model = nil
        #expect(released == nil)
    }

    private func layoutSnapshot(_ id: String) -> MenuBarSnapshot {
        MenuBarSnapshot(icons: [.init(id: id, title: id, bundleID: nil, frame: .zero, section: .shown, target: nil)], dividers: [:])
    }
}

@MainActor
private final class FakeShortcutDelivery: ShortcutDeliveryWatching {
    var callback: ((Int64, CGEventTimestamp, pid_t) -> Void)?
    func start(onDelivered: @escaping (Int64, CGEventTimestamp, pid_t) -> Void) -> Bool { callback = onDelivered; return true }
    func stop() { callback = nil }
}

@MainActor
private final class SnapshotGate {
    private let signal = AsyncStream<Void>.makeStream()
    private var continuation: CheckedContinuation<MenuBarSnapshot, Never>?
    func wait() async -> MenuBarSnapshot {
        await withCheckedContinuation {
            continuation = $0
            signal.continuation.yield(())
        }
    }
    func started() async { var iterator = signal.stream.makeAsyncIterator(); await iterator.next() }
    func resume(_ snapshot: MenuBarSnapshot) { continuation?.resume(returning: snapshot); continuation = nil }
}
