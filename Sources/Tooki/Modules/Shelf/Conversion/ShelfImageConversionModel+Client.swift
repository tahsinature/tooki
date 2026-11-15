import Foundation
import ShelfFeature
import TookiKit

extension ShelfImageConversionModel {
    func makeClient() -> ShelfConversionClient {
        ShelfConversionClient(
            validate: { [weak self] metadata in
                try await MainActor.run {
                    guard let self, let shelf = self.shelf, shelf.canConvertImages(self.originalItems.filter { item in metadata.contains { $0.id == item.id } })
                    else { throw ImageConversionError.unsupported }
                }
                await Task.detached { ConversionPreviewStorage.pruneExpired() }.value
            },
            prepare: { item, options in
                try await Task.detached(priority: .userInitiated) {
                    try ImageConversionPreview.create(source: item.url, options: options)
                }.value
            },
            details: { preview in
                try await Task.detached(priority: .utility) { try preview.details() }.value
            },
            save: { [weak self] result, output in
                guard let self else { throw ImageConversionError.itemRemoved }
                return try await self.saveResult(result, output: output)
            },
            discard: { preview in await Task.detached { preview.discard() }.value },
            didSave: { [weak self] rows in
                await MainActor.run {
                    guard let self else { return }
                    self.shelf?.selectConverted(rows)
                    self.onSaved(rows)
                }
            },
            dismissPreview: { [weak self] in await self?.dismissPreview() },
            close: { [weak self] in await self?.closeNative() }
        )
    }

    private func saveResult(_ result: ShelfConversionResult, output: ImageConversionOptions.Output) async throws -> UUID {
        guard let shelf, let original = originalItems.first(where: { $0.id == result.item.id })
        else { throw ImageConversionError.itemRemoved }
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
            return try shelf.applyImageConversion(prepared, to: original, output: output)
        } catch {
            if output == .copy { ShelfStorage.deleteFolder(of: destination) }
            throw error
        }
    }
}
