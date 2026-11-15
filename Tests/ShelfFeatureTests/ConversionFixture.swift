import CoreGraphics
import Foundation
import ImageIO
import ShelfFeature
import Testing
import TookiKit

struct ConversionFixture {
    let folder: URL
    let item: ShelfConversionItem
    let result: ShelfConversionResult

    init(name: String = "photo.png") throws {
        folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appending(path: name)
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(source as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        item = ShelfConversionItem(id: UUID(), url: source, name: name, ownsFile: false)
        let preview = try ImageConversionPreview.create(source: source, options: ImageConversionOptions())
        result = try ShelfConversionResult(id: UUID(), item: item, preview: preview,
                                          details: preview.details(), revision: UUID())
    }

    func cleanUp() {
        result.preview.discard()
        try? FileManager.default.removeItem(at: folder)
    }
}
