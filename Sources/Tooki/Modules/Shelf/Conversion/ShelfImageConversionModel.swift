import AppKit
import Observation
import TookiKit

@MainActor
@Observable
final class ShelfImageConversionModel: Identifiable {
    enum Phase { case settings, converting, review, saving }

    let id = UUID()
    let previousWasExpanded: Bool
    @ObservationIgnored var onSaved: ([UUID]) -> Void = { _ in }
    @ObservationIgnored var showPreview: (([URL]) -> Void)?
    @ObservationIgnored var closePreview: (() -> Void)?
    @ObservationIgnored private let onClose: (() -> Void)?
    private(set) var items: [ShelfItem]
    var options = ImageConversionOptions()
    private(set) var phase = Phase.settings
    private(set) var results: [ShelfConversionResult] = []
    private(set) var completed = 0
    private(set) var errors: [String] = []
    var reviewIndex = 0
    @ObservationIgnored private weak var shelf: Shelf?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var isClosed = false
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var failedPreparation: [UUID: String] = [:]

    init(items: [ShelfItem], shelf: Shelf, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        previousWasExpanded = shelf.isExpanded
        self.items = items
        self.shelf = shelf
    }

    func convert() {
        guard phase == .settings, let shelf else { return }
        guard shelf.canConvertImages(items) else {
            errors = [ImageConversionError.unsupported.localizedDescription]
            return
        }
        discardResults()
        phase = .converting
        completed = 0
        errors = []
        failedPreparation = [:]
        let options = options
        work = Task {
            await Task.detached { ConversionPreviewStorage.pruneExpired() }.value
            for item in items {
                if Task.isCancelled || isClosed { break }
                do {
                    let source = item.url
                    let (preview, details) = try await Task.detached(priority: .userInitiated) {
                        let preview = try ImageConversionPreview.create(source: source, options: options)
                        do { return (preview, try preview.details()) }
                        catch { preview.discard(); throw error }
                    }.value
                    if Task.isCancelled || isClosed { preview.discard(); break }
                    results.append(ShelfConversionResult(item: item, preview: preview, details: details))
                } catch {
                    if !isClosed {
                        let message = "\(item.name): \(error.localizedDescription)"
                        failedPreparation[item.id] = message
                        errors.append(message)
                    }
                }
                completed += 1
            }
            guard !isClosed else { return }
            reviewIndex = 0
            phase = results.isEmpty ? .settings : .review
        }
    }

    func save(_ output: ImageConversionOptions.Output) {
        guard canSave, let shelf else { return }
        phase = .saving
        completed = 0
        errors = Array(failedPreparation.values)
        let pending = results
        work = Task {
            var savedSources: Set<UUID> = []
            var savedRows: [UUID] = []
            for result in pending {
                let destination = output == .copy
                    ? ShelfStorage.newFolder().appending(path: result.preview.url.deletingPathExtension().lastPathComponent + "-converted." + result.preview.format.fileExtension)
                    : replacementURL(for: result)
                do {
                    let prepared = try await Task.detached(priority: .userInitiated) {
                        if output == .copy {
                            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                        }
                        return try result.preview.prepareSave(to: destination, replacingSource: output == .replace, reviewed: result.details)
                    }.value
                    defer { prepared.discard() }
                    guard !isClosed else { throw ImageConversionError.itemRemoved }
                    let row = try shelf.applyImageConversion(prepared, to: result.item, output: output)
                    savedRows.append(row)
                    savedSources.insert(result.item.id)
                    if !result.wasOpened { result.preview.discard() }
                } catch {
                    if output == .copy { ShelfStorage.deleteFolder(of: destination) }
                    errors.append("\(result.item.name): \(error.localizedDescription)")
                }
                completed += 1
            }
            shelf.selectConverted(savedRows)
            onSaved(savedRows)
            results.removeAll { savedSources.contains($0.item.id) }
            items.removeAll { savedSources.contains($0.id) }
            if items.isEmpty {
                close()
            } else {
                reviewIndex = 0
                phase = results.isEmpty ? .settings : .review
                await refreshPreviews()
            }
        }
    }

    /// Also runs on returning from an editor. Saving independently checks the reviewed
    /// fingerprint, so an edit between this refresh and the click cannot be applied unseen.
    func refreshPreviews() async {
        guard phase == .review, !isRefreshing, !isClosed else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for result in results {
            let updated = await Task.detached(priority: .utility) { Result { try result.preview.details() } }.value
            guard phase == .review, !isClosed, let index = results.firstIndex(where: { $0.id == result.id }) else { return }
            switch updated {
            case .success(let details):
                if details != results[index].details {
                    results[index].details = details
                    results[index].revision = UUID()
                }
                results[index].error = nil
            case .failure(let error):
                results[index].error = error.localizedDescription
            }
        }
    }

    func markOpened(_ ids: Set<UUID>) {
        for index in results.indices where ids.contains(results[index].id) { results[index].wasOpened = true }
    }

    func quickLook() {
        guard phase == .review, let current else { return }
        markOpened(Set(results.map(\.id)))
        // The current result comes first; Quick Look can browse the whole batch.
        let ordered = [current.preview.url] + results.filter { $0.id != current.id }.map(\.preview.url)
        if let showPreview { showPreview(ordered) } else { shelf?.onQuickLook(ordered) }
    }

    func back() {
        guard phase != .saving else { return }
        if phase == .review {
            dismissPreview()
            discardResults()
            phase = .settings
            errors = []
        } else {
            discard()
        }
    }

    func discard() {
        guard phase != .saving else { return }
        work?.cancel()
        close()
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        dismissPreview()
        discardResults()
        if let onClose { onClose() } else { shelf?.endImageConversion(self) }
    }

    private func dismissPreview() {
        if let closePreview { closePreview() } else { shelf?.onCloseQuickLook() }
    }

    private func discardResults() {
        results.filter { !$0.wasOpened }.forEach { $0.preview.discard() }
        results = []
        reviewIndex = 0
    }
}
