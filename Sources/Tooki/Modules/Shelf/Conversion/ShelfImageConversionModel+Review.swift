import Foundation
import TookiKit
import UniformTypeIdentifiers

extension ShelfImageConversionModel {
    var isBusy: Bool { phase == .converting || phase == .saving }
    var current: ShelfConversionResult? { results.indices.contains(reviewIndex) ? results[reviewIndex] : nil }
    var canSave: Bool { phase == .review && !results.isEmpty && results.allSatisfy { $0.error == nil } }
    var title: String { items.count == 1 ? "Convert image" : "Convert \(items.count) images" }
    var name: String { items.count == 1 ? (items.first?.name ?? "Image") : "\(items.count) images selected" }
    var inputSize: String { items.compactMap(\.byteSize).reduce(0, +).formatted(.byteCount(style: .file)) }
    var saveCopyTitle: String { results.count == 1 ? "Save a copy" : "Save \(results.count) copies" }

    var replaceTitle: String {
        let owned = results.filter { $0.item.ownsFile }.count
        if owned == results.count {
            return results.count == 1 ? "Replace shelf copy" : "Replace \(results.count) shelf copies"
        }
        if owned == 0 { return results.count == 1 ? "Replace original" : "Replace \(results.count) originals" }
        return "Replace selected files"
    }

    var replaceExplanation: String {
        let owned = results.filter { $0.item.ownsFile }.count
        if owned == results.count { return "Replaces only Tooki’s stored copies. Source files stay unchanged." }
        if owned == 0 { return "Replace changes the original \(results.count == 1 ? "file" : "files") on disk." }
        return "Replaces \(results.count - owned) original files on disk and \(owned) Tooki shelf copies."
    }

    var totalSizeChange: String {
        let before = results.reduce(Int64(0)) { $0 + $1.preview.sourceByteCount }
        let after = results.reduce(Int64(0)) { $0 + $1.details.byteCount }
        return "Total: \(before.formatted(.byteCount(style: .file))) → \(after.formatted(.byteCount(style: .file)))"
    }

    var reviewURLs: [URL] {
        guard let current else { return [] }
        return [current.preview.url] + results.filter { $0.id != current.id }.map(\.preview.url)
    }

    func moveReview(by offset: Int) {
        guard phase == .review else { return }
        reviewIndex = min(max(reviewIndex + offset, 0), max(results.count - 1, 0))
    }

    func replacementURL(for result: ShelfConversionResult) -> URL {
        let source = result.item.url
        if UTType(filenameExtension: source.pathExtension) == UTType(filenameExtension: result.preview.format.fileExtension) {
            return source
        }
        return source.deletingPathExtension().appendingPathExtension(result.preview.format.fileExtension)
    }
}
