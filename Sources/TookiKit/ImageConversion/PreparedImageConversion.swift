import Foundation

/// A completed conversion waiting to be committed. Discard it if its shelf item went away.
public struct PreparedImageConversion: Sendable {
    public let source: URL
    public let destination: URL
    let temporary: URL
    let fingerprint: ImageFileFingerprint?
    let replacesSource: Bool

    public func discard() {
        try? FileManager.default.removeItem(at: temporary)
    }

    /// File renames only, after the expensive image work has finished.
    @discardableResult
    public func commit() throws -> URL {
        if let fingerprint, (try? ImageFileFingerprint(url: source)) != fingerprint {
            throw ImageConversionError.sourceChanged
        }
        let files = FileManager.default
        if source == destination {
            _ = try files.replaceItemAt(source, withItemAt: temporary)
        } else {
            guard !files.fileExists(atPath: destination.path) else {
                throw ImageConversionError.destinationExists
            }
            // moveItem fails if the destination appears after the existence check.
            try files.moveItem(at: temporary, to: destination)
            if replacesSource { try retireSource() }
        }
        return destination
    }

    /// Called only for Replace file when the output extension changed. If retiring the
    /// source fails, remove the new output so the shelf can continue using the source.
    private func retireSource() throws {
        guard source != destination else { return }
        do {
            try FileManager.default.removeItem(at: source)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
