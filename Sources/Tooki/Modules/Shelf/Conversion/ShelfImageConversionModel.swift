import AppKit
import ComposableArchitecture
import Observation
import ShelfFeature
import TookiKit

/// Connects reducer-owned conversion state to native shelf files and preview windows.
@MainActor
@Observable
final class ShelfImageConversionModel: Identifiable {
    typealias Phase = ShelfImageConversionFeature.Phase
    let id = UUID()
    let previousWasExpanded: Bool
    @ObservationIgnored var onSaved: ([UUID]) -> Void = { _ in }
    @ObservationIgnored var showPreview: (([URL]) -> Void)?
    @ObservationIgnored var closePreview: (() -> Void)?
    @ObservationIgnored private let onClose: (() -> Void)?
    @ObservationIgnored weak var shelf: Shelf?
    let originalItems: [ShelfItem]
    private let initialState: ShelfImageConversionFeature.State
    @ObservationIgnored private(set) lazy var store = Store(
        initialState: initialState
    ) { ShelfImageConversionFeature() } withDependencies: {
        $0.shelfConversionClient = self.makeClient()
    }

    init(items: [ShelfItem], shelf: Shelf, initialState: ShelfImageConversionFeature.State? = nil,
         onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        previousWasExpanded = shelf.isExpanded
        originalItems = items
        self.initialState = initialState ?? ShelfImageConversionFeature.State(items: items.map(\.conversionMetadata))
        self.shelf = shelf
    }

    var items: [ShelfItem] {
        let ids = Set(store.items.map(\.id))
        return originalItems.filter { ids.contains($0.id) }
    }
    var options: ImageConversionOptions {
        get { store.options }
        set { store.send(.optionsChanged(newValue)) }
    }
    var phase: Phase { store.phase }
    var results: [ShelfConversionResult] { store.results }
    var completed: Int { store.completed }
    var errors: [String] { store.errors }
    var reviewIndex: Int { store.reviewIndex }

    func convert() { store.send(.convert) }
    func save(_ output: ImageConversionOptions.Output) { store.send(.save(output)) }
    func back() { store.send(.back) }
    func discard() { store.send(.discard) }
    func refreshPreviews() async { await store.send(.refresh).finish() }
    func markOpened(_ ids: Set<UUID>) { store.send(.markOpened(ids)) }
    func moveReview(by offset: Int) { store.send(.moveReview(offset)) }

    func quickLook() {
        guard phase == .review, let current else { return }
        markOpened(Set(results.map(\.id)))
        let ordered = [current.preview.url] + results.filter { $0.id != current.id }.map(\.preview.url)
        if let showPreview { showPreview(ordered) } else { shelf?.onQuickLook(ordered) }
    }

    func dismissPreview() {
        if let closePreview { closePreview() } else { shelf?.onCloseQuickLook() }
    }

    func closeNative() {
        if let onClose { onClose() } else { shelf?.endImageConversion(self) }
    }
}

extension ShelfItem {
    var conversionMetadata: ShelfConversionItem {
        ShelfConversionItem(id: id, url: url, name: name, ownsFile: ownsFile)
    }
}
