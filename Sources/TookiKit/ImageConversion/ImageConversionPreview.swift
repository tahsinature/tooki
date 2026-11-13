import Foundation

/// An inspectable, editable result. Creating it never changes the source or shelf.
public struct ImageConversionPreview: Sendable {
    public let source: URL
    public let url: URL
    public let format: ImageConversionOptions.Format
    public var sourceByteCount: Int64 { Int64(sourceFingerprint.byteCount) }
    private let sourceFingerprint: ImageFileFingerprint

    public static func create(source: URL, options: ImageConversionOptions) throws -> Self {
        let folder = ConversionPreviewStorage.newFolder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: folder) } }
        let url = folder.appending(path: source.deletingPathExtension().lastPathComponent + "." + options.format.fileExtension)
        var stagingOptions = options
        stagingOptions.output = .copy
        let prepared = try ImageConverter.prepare(source: source, destination: url, options: stagingOptions)
        defer { prepared.discard() }
        try prepared.commit()
        guard let fingerprint = prepared.fingerprint else { throw ImageConversionError.sourceChanged }
        let preview = Self(source: prepared.source, url: url, format: options.format,
                           sourceFingerprint: fingerprint)
        _ = try preview.details()
        completed = true
        return preview
    }

    public func details() throws -> ImagePreviewDetails {
        try ImagePreviewDetails(url: url, format: format)
    }

    /// Copy the reviewed result to the destination's volume before committing its row.
    /// External edits after review require another review, rather than silently saving.
    public func prepareSave(
        to destination: URL, replacingSource: Bool, reviewed: ImagePreviewDetails
    ) throws -> PreparedImageConversion {
        guard try details() == reviewed else { throw ImageConversionError.previewChanged }
        if replacingSource, (try? ImageFileFingerprint(url: source)) != sourceFingerprint {
            throw ImageConversionError.sourceChanged
        }
        let temporary = destination.deletingLastPathComponent().appending(path: ".tooki-convert-\(UUID().uuidString)")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: temporary) } }
        try FileManager.default.copyItem(at: url, to: temporary)
        guard try details() == reviewed else { throw ImageConversionError.previewChanged }
        _ = try ImagePreviewDetails(url: temporary, format: format)
        completed = true
        return PreparedImageConversion(source: source, destination: destination.standardizedFileURL,
                                       temporary: temporary, fingerprint: replacingSource ? sourceFingerprint : nil,
                                       replacesSource: replacingSource)
    }

    public func discard() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
