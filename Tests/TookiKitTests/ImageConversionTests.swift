import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import TookiKit

struct ImageConversionTests {
    @Test func mixedImageFormatsAreAcceptedButOtherFilesAreNot() throws {
        try withFolder { folder in
            let png = try fixture(folder, name: "a.png")
            let jpg = try fixture(folder, name: "b.jpg", type: UTType.jpeg.identifier)
            let text = folder.appending(path: "notes.txt")
            try Data("hello".utf8).write(to: text)
            #expect(ImageConverter.supports([png, jpg]))
            #expect(!ImageConverter.supports([png, text]))
            #expect(!ImageConverter.supports([png, folder]))
            #expect(!ImageConverter.supports([]))
            #expect(!ImageConverter.supports([folder.appending(path: "missing.png")]))
            let link = folder.appending(path: "linked.png")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: png)
            #expect(!ImageConverter.supports([link]))
        }
    }

    @Test func newCopyLeavesOriginalBytesUntouched() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let bytes = try Data(contentsOf: source)
            var options = ImageConversionOptions()
            options.output = .copy
            let destination = folder.appending(path: "converted.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: options)
            defer { prepared.discard() }
            #expect(!FileManager.default.fileExists(atPath: destination.path))
            try prepared.commit()
            #expect(try Data(contentsOf: source) == bytes)
            #expect(type(of: destination) == UTType.jpeg.identifier)
        }
    }

    @Test func replacementChangesExtensionAndRetiresSourceOnlyOnCommit() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let destination = folder.appending(path: "photo.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: .init())
            defer { prepared.discard() }
            #expect(FileManager.default.fileExists(atPath: source.path))
            try prepared.commit()
            #expect(!FileManager.default.fileExists(atPath: source.path))
            #expect(type(of: destination) == UTType.jpeg.identifier)
        }
    }

    @Test func sameExtensionReplacementIsReadable() throws {
        try withFolder { folder in
            let source = try fixture(folder, name: "photo.jpg", type: UTType.jpeg.identifier)
            let prepared = try ImageConverter.prepare(source: source, destination: source, options: .init())
            defer { prepared.discard() }
            try prepared.commit()
            #expect(type(of: source) == UTType.jpeg.identifier)
            #expect(CGImageSourceCreateImageAtIndex(try imageSource(source), 0, nil) != nil)
        }
    }

    @Test func existingDestinationAndLateCollisionKeepBothFilesIntact() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let bytes = try Data(contentsOf: source)
            let destination = folder.appending(path: "photo.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: .init())
            defer { prepared.discard() }
            let other = Data("existing file".utf8)
            try other.write(to: destination)
            #expect(throws: ImageConversionError.self) { try prepared.commit() }
            #expect(throws: ImageConversionError.self) {
                try ImageConverter.prepare(source: source, destination: destination, options: .init())
            }
            #expect(try Data(contentsOf: source) == bytes)
            #expect(try Data(contentsOf: destination) == other)
        }
    }

    @Test func changedSourceIsNeverOverwritten() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let destination = folder.appending(path: "photo.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: .init())
            defer { prepared.discard() }
            let changed = Data("new source contents".utf8)
            try changed.write(to: source)
            #expect(throws: ImageConversionError.self) { try prepared.commit() }
            #expect(try Data(contentsOf: source) == changed)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @Test func resizeNormalizesOrientationAndKeepsAspectRatio() throws {
        try withFolder { folder in
            let source = try fixture(folder, name: "portrait.jpg", type: UTType.jpeg.identifier,
                                     width: 1600, height: 800, properties: [kCGImagePropertyOrientation: 6])
            var options = ImageConversionOptions()
            options.size = .small
            let destination = folder.appending(path: "small.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: options)
            defer { prepared.discard() }
            try prepared.commit()
            let properties = try properties(destination)
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 320)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 640)
            #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        }
    }

    @Test func smallerImagesAreNotUpscaled() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            var options = ImageConversionOptions()
            options.size = .small
            let destination = folder.appending(path: "small.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: options)
            defer { prepared.discard() }
            try prepared.commit()
            #expect(try properties(destination)[kCGImagePropertyPixelWidth] as? Int == 80)
        }
    }

    @Test(arguments: [true, false]) func metadataPreferenceControlsGPS(_ preserve: Bool) throws {
        try withFolder { folder in
            let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 43.65, kCGImagePropertyGPSLatitudeRef: "N",
                                       kCGImagePropertyGPSLongitude: 79.38, kCGImagePropertyGPSLongitudeRef: "W"]
            let source = try fixture(folder, name: "photo.jpg", type: UTType.jpeg.identifier,
                                     properties: [kCGImagePropertyGPSDictionary: gps])
            #expect(try properties(source)[kCGImagePropertyGPSDictionary] != nil)
            var options = ImageConversionOptions()
            options.preserveMetadata = preserve
            let destination = folder.appending(path: "result.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: options)
            defer { prepared.discard() }
            try prepared.commit()
            #expect((try properties(destination)[kCGImagePropertyGPSDictionary] != nil) == preserve)
        }
    }

    @Test func transparentPixelsBecomeWhiteInJPEG() throws {
        try withFolder { folder in
            let source = try fixture(folder, alpha: 0)
            let destination = folder.appending(path: "white.jpg")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: .init())
            defer { prepared.discard() }
            try prepared.commit()
            let image = try #require(CGImageSourceCreateImageAtIndex(try imageSource(destination), 0, nil))
            let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let pixel = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            #expect(pixel[0] > 240 && pixel[1] > 240 && pixel[2] > 240)
        }
    }

    @Test func corruptImageAndAnimationFailWithoutChangingSources() throws {
        try withFolder { folder in
            let corrupt = folder.appending(path: "bad.png")
            let bytes = Data("not image data".utf8)
            try bytes.write(to: corrupt)
            #expect(throws: ImageConversionError.self) {
                try ImageConverter.prepare(source: corrupt, destination: folder.appending(path: "bad.jpg"), options: .init())
            }
            #expect(try Data(contentsOf: corrupt) == bytes)
            let animated = try fixture(folder, name: "animated.gif", type: UTType.gif.identifier, frames: 2)
            let animatedBytes = try Data(contentsOf: animated)
            #expect(throws: ImageConversionError.self) {
                try ImageConverter.prepare(source: animated, destination: folder.appending(path: "animated.jpg"), options: .init())
            }
            #expect(try Data(contentsOf: animated) == animatedBytes)
        }
    }

    @Test func copyCannotOverwriteItsSourceAndDiscardRemovesStagingFile() throws {
        try withFolder { folder in
            let source = try fixture(folder, name: "photo.jpg", type: UTType.jpeg.identifier)
            var options = ImageConversionOptions()
            options.output = .copy
            #expect(throws: ImageConversionError.self) {
                try ImageConverter.prepare(source: source, destination: source, options: options)
            }
            let prepared = try ImageConverter.prepare(source: source, destination: folder.appending(path: "copy.jpg"), options: options)
            #expect(FileManager.default.fileExists(atPath: prepared.temporary.path))
            prepared.discard()
            #expect(!FileManager.default.fileExists(atPath: prepared.temporary.path))
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test(arguments: ImageConversionOptions.Format.allCases) func eachAvailableFormatEncodes(_ format: ImageConversionOptions.Format) throws {
        guard ImageConverter.availableFormats.contains(format) else { return }
        try withFolder { folder in
            let source = try fixture(folder)
            var options = ImageConversionOptions()
            options.format = format
            let destination = folder.appending(path: "result.\(format.fileExtension)")
            let prepared = try ImageConverter.prepare(source: source, destination: destination, options: options)
            defer { prepared.discard() }
            try prepared.commit()
            #expect(type(of: destination) == format.identifier)
            #expect(ImageConverter.supports([destination]))
        }
    }

    @Test func previewUsesActualBytesAndLeavesSourceUntouched() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let before = try Data(contentsOf: source)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            defer { preview.discard() }
            let details = try preview.details()
            #expect(preview.url.pathExtension == "jpg")
            #expect(details.byteCount == Int64(try Data(contentsOf: preview.url).count))
            #expect(details.width == 80 && details.height == 40)
            #expect(try Data(contentsOf: source) == before)
            #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "photo.jpg").path))
        }
    }

    @Test func reviewedPreviewCanBeSavedEitherWayWithoutReencoding() throws {
        for replace in [false, true] {
            try withFolder { folder in
                let source = try fixture(folder)
                let original = try Data(contentsOf: source)
                let preview = try ImageConversionPreview.create(source: source, options: .init())
                defer { preview.discard() }
                let bytes = try Data(contentsOf: preview.url)
                let destination = folder.appending(path: "photo.jpg")
                let staged = try preview.prepareSave(to: destination, replacingSource: replace, reviewed: preview.details())
                defer { staged.discard() }
                #expect(try Data(contentsOf: source) == original)
                try staged.commit()
                #expect(try Data(contentsOf: destination) == bytes)
                #expect(FileManager.default.fileExists(atPath: source.path) == !replace)
                #expect(try Data(contentsOf: preview.url) == bytes)
            }
        }
    }

    @Test func externalEditsRequireReviewAndCanThenBeSaved() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            defer { preview.discard() }
            let reviewed = try preview.details()
            let edited = try fixture(folder, name: "edited.jpg", type: UTType.jpeg.identifier, width: 240, height: 120)
            let editedBytes = try Data(contentsOf: edited)
            try editedBytes.write(to: preview.url)
            let destination = folder.appending(path: "result.jpg")
            #expect(throws: ImageConversionError.self) {
                try preview.prepareSave(to: destination, replacingSource: false, reviewed: reviewed)
            }
            let updated = try preview.details()
            #expect(updated.width == 240 && updated.height == 120)
            let staged = try preview.prepareSave(to: destination, replacingSource: false, reviewed: updated)
            defer { staged.discard() }
            try staged.commit()
            #expect(try Data(contentsOf: destination) == editedBytes)
        }
    }

    @Test func changedSourceBlocksReplaceButAllowsSavingCopy() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            defer { preview.discard() }
            let reviewed = try preview.details()
            let changed = Data("changed source".utf8)
            try changed.write(to: source)
            let destination = folder.appending(path: "saved.jpg")
            #expect(throws: ImageConversionError.self) {
                try preview.prepareSave(to: destination, replacingSource: true, reviewed: reviewed)
            }
            let staged = try preview.prepareSave(to: destination, replacingSource: false, reviewed: reviewed)
            defer { staged.discard() }
            try staged.commit()
            #expect(try Data(contentsOf: source) == changed)
            #expect(try Data(contentsOf: destination) == Data(contentsOf: preview.url))
        }
    }

    @Test func previewWithDifferentFormatOrInvalidBytesIsRejected() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            defer { preview.discard() }
            let reviewed = try preview.details()
            try Data(contentsOf: source).write(to: preview.url)
            #expect(throws: ImageConversionError.self) { try preview.details() }
            #expect(throws: ImageConversionError.self) {
                try preview.prepareSave(to: folder.appending(path: "out.jpg"), replacingSource: true, reviewed: reviewed)
            }
            try Data("broken preview".utf8).write(to: preview.url)
            #expect(throws: ImageConversionError.self) { try preview.details() }
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test func previewWorksEvenWhenReplacementNameExists() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let destination = folder.appending(path: "photo.jpg")
            let existing = Data("another file".utf8)
            try existing.write(to: destination)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            defer { preview.discard() }
            let staged = try preview.prepareSave(to: destination, replacingSource: true, reviewed: preview.details())
            defer { staged.discard() }
            #expect(throws: ImageConversionError.self) { try staged.commit() }
            #expect(try Data(contentsOf: destination) == existing)
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test func discardingPreviewOnlyRemovesTemporaryFiles() throws {
        try withFolder { folder in
            let source = try fixture(folder)
            let bytes = try Data(contentsOf: source)
            let preview = try ImageConversionPreview.create(source: source, options: .init())
            preview.discard()
            #expect(!FileManager.default.fileExists(atPath: preview.url.deletingLastPathComponent().path))
            #expect(try Data(contentsOf: source) == bytes)
        }
    }

    @Test func coffeeIconPreferenceMigratesAndRoundTrips() throws {
        let legacy = Data(#"{"mode":"display","defaultDurationMinutes":15,"onlyOnPower":true,"activateForApps":[]}"#.utf8)
        let settings = try JSONDecoder().decode(KeepAwakeConfig.self, from: legacy)
        #expect(!settings.showMenuBarIcon && settings.onlyOnPower)
        var enabled = settings
        enabled.showMenuBarIcon = true
        let restored = try JSONDecoder().decode(KeepAwakeConfig.self, from: JSONEncoder().encode(enabled))
        #expect(restored == enabled)
    }

    private func withFolder(_ test: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tooki-conversion-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try test(folder)
    }

    private func fixture(_ folder: URL, name: String = "photo.png", type: String = UTType.png.identifier,
                         width: Int = 80, height: Int = 40, properties: [CFString: Any] = [:], frames: Int = 1, alpha: CGFloat = 1) throws -> URL {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: alpha))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let url = folder.appending(path: name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, frames, nil))
        for _ in 0..<frames { CGImageDestinationAddImage(destination, image, properties as CFDictionary) }
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    private func imageSource(_ url: URL) throws -> CGImageSource {
        try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    }

    private func properties(_ url: URL) throws -> [CFString: Any] {
        try #require(CGImageSourceCopyPropertiesAtIndex(try imageSource(url), 0, nil) as? [CFString: Any])
    }

    private func type(of url: URL) -> String? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceGetType($0) as String? }
    }
}
