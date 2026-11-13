import Foundation
import ImageIO

public struct ImagePreviewDetails: Sendable, Equatable {
    public let byteCount: Int64
    public let width: Int
    public let height: Int
    let fingerprint: ImageFileFingerprint

    init(url: URL, format: ImageConversionOptions.Format) throws {
        let fingerprint = try ImageFileFingerprint(url: url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetType(source) as String? == format.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { throw ImageConversionError.invalidPreview }
        self.fingerprint = fingerprint
        byteCount = Int64(fingerprint.byteCount)
        self.width = width
        self.height = height
    }
}
