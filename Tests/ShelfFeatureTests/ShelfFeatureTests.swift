import ComposableArchitecture
import Foundation
import ShelfFeature
import Testing

@MainActor
struct ShelfFeatureTests {
    @Test func selectionSupportsKeyboardExtensionAndRemoval() async {
        let ids = (0..<4).map { _ in UUID() }
        let store = TestStore(initialState: ShelfFeature.State(itemIDs: ids)) { ShelfFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.moveSelection(-1, extending: false))
        #expect(store.state.cursor == ids.last)
        await store.send(.moveSelection(Int.min, extending: true))
        #expect(store.state.selection == [ids[0], ids[3]])
        await store.send(.clicked(ids[0], extending: true))
        #expect(store.state.selection == [ids[3]])
        await store.send(.showDetail(ids[3]))
        await store.send(.expanded(true))
        await store.send(.itemsChanged([]))
        #expect(store.state.selection.isEmpty)
        #expect(store.state.cursor == nil)
        #expect(!store.state.isShowingDetail)
        #expect(!store.state.isExpanded)
    }

    @Test func rearmingRestartsConfirmationExpiry() async {
        let clock = TestClock()
        let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.arm(.clear)) { $0.armed = .clear }
        await clock.advance(by: .seconds(3))
        await store.send(.arm(.delete)) { $0.armed = .delete }
        await clock.advance(by: .seconds(3))
        #expect(store.state.armed == .delete)
        await clock.advance(by: .seconds(1))
        await store.receive(.disarm) { $0.armed = nil }
        await store.finish()
    }

    @Test func managerSearchRenameAndBackPreserveExpectedSelection() async {
        let item = ShelfSummary.Item(id: UUID(), name: "Report.pdf")
        let first = ShelfSummary(id: UUID(), name: "Work", lastUsed: Date(timeIntervalSince1970: 1), items: [item])
        let second = ShelfSummary(id: UUID(), name: "Personal", lastUsed: Date(timeIntervalSince1970: 2), items: [])
        let store = TestStore(initialState: ShelfManagerFeature.State(shelves: [first, second])) { ShelfManagerFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        #expect(store.state.visibleShelves.map(\.id) == [second.id, first.id])
        await store.send(.queryChanged("report"))
        #expect(store.state.visibleShelves.map(\.id) == [first.id])
        await store.send(.startRenaming(first.id))
        await store.send(.queryChanged("Renamed"))
        #expect(store.state.visibleShelves.count == 2)
        await store.send(.moveSelection(Int.max))
        #expect(store.state.selectedShelfID == first.id)
        await store.send(.finishRenaming)
        await store.send(.open(first.id))
        #expect(store.state.selectedItem?.id == item.id)
        await store.send(.closeShelf)
        #expect(store.state.selectedShelfID == first.id)
    }

    @Test func managerBoundsNavigationAndFreezesItDuringConversion() async {
        let shelves = (0..<5).map { ShelfSummary(id: UUID(), name: "Shelf \($0)", lastUsed: Date(timeIntervalSince1970: Double($0)), items: []) }
        let store = TestStore(initialState: ShelfManagerFeature.State(shelves: shelves)) { ShelfManagerFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.moveSelection(Int.max))
        #expect(store.state.selectedShelfID == shelves.first?.id)
        await store.send(.conversionPresented(true))
        await store.send(.moveSelection(Int.min))
        #expect(store.state.selectedShelfID == shelves.first?.id)
        await store.send(.conversionPresented(false))
        await store.send(.moveSelection(Int.min))
        #expect(store.state.selectedShelfID == shelves.last?.id)
    }
}
