import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageConverter {
    private static let readableTypes = Set(CGImageSourceCopyTypeIdentifiers() as! [String])
    private static let writableTypes = Set(CGImageDestinationCopyTypeIdentifiers() as! [String])

    public static var availableFormats: [ImageConversionOptions.Format] {
        ImageConversionOptions.Format.allCases.filter { writableTypes.contains($0.identifier) }
    }

    /// Header/type checks only. Decode and validation run off the main thread later.
    public static func supports(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { url in
            guard let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let type = values.contentType, type.conforms(to: .image)
            else { return false }
            return readableTypes.contains(type.identifier)
        }
    }

    /// Call off the main thread. Writes beside the destination, leaving the source intact.
    public static func prepare(
        source url: URL, destination: URL, options: ImageConversionOptions
    ) throws -> PreparedImageConversion {
        let sourceURL = url.standardizedFileURL
        let destination = destination.standardizedFileURL
        guard supports([sourceURL]), writableTypes.contains(options.format.identifier) else {
            throw ImageConversionError.unsupported
        }
        guard options.output != .copy || sourceURL != destination else {
            throw ImageConversionError.destinationExists
        }
        let fingerprint = try ImageFileFingerprint(url: sourceURL)
        if sourceURL != destination, FileManager.default.fileExists(atPath: destination.path) {
            throw ImageConversionError.destinationExists
        }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw ImageConversionError.unreadable }
        guard CGImageSourceGetCount(source) == 1 else { throw ImageConversionError.animated }
        let maxSize = min(options.size.maxPixelSize ?? max(width, height), max(width, height))
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary) else {
            throw ImageConversionError.unreadable
        }
        let temporary = destination.deletingLastPathComponent().appending(path: ".tooki-convert-\(UUID().uuidString)")
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: temporary) } }
        guard let writer = CGImageDestinationCreateWithURL(temporary as CFURL, options.format.identifier as CFString, 1, nil) else {
            throw ImageConversionError.encodingFailed
        }
        let outputProperties = outputProperties(properties, image: image, options: options)
        CGImageDestinationAddImage(writer, image, outputProperties as CFDictionary)
        guard CGImageDestinationFinalize(writer),
              let result = CGImageSourceCreateWithURL(temporary as CFURL, nil),
              CGImageSourceGetStatus(result) == .statusComplete
        else { throw ImageConversionError.encodingFailed }
        guard try ImageFileFingerprint(url: sourceURL) == fingerprint else {
            throw ImageConversionError.sourceChanged
        }
        completed = true
        return PreparedImageConversion(source: sourceURL, destination: destination, temporary: temporary, fingerprint: fingerprint, replacesSource: options.output == .replace)
    }

    private static func outputProperties(
        _ original: [CFString: Any], image: CGImage, options: ImageConversionOptions
    ) -> [CFString: Any] {
        var result = options.preserveMetadata ? original : [:]
        // ThumbnailWithTransform has already applied orientation to the pixels.
        result[kCGImagePropertyOrientation] = 1
        result[kCGImagePropertyPixelWidth] = image.width
        result[kCGImagePropertyPixelHeight] = image.height
        if var tiff = result[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            result[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var exif = result[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = image.width
            exif[kCGImagePropertyExifPixelYDimension] = image.height
            result[kCGImagePropertyExifDictionary] = exif
        }
        result[kCGImageDestinationLossyCompressionQuality] = 0.9
        result[kCGImageDestinationBackgroundColor] = CGColor(gray: 1, alpha: 1)
        return result
    }
}
