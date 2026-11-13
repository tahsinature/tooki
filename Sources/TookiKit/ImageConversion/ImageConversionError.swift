import Foundation

public enum ImageConversionError: LocalizedError {
    case unsupported, animated, unreadable, encodingFailed, sourceChanged, destinationExists, itemRemoved, previewChanged, invalidPreview

    public var errorDescription: String? {
        switch self {
        case .unsupported: "Select only supported image files. PDFs, folders, links and text cannot be converted."
        case .animated: "Animated and multi-image files cannot be converted without losing frames."
        case .unreadable: "The image could not be read. It may be damaged or unavailable."
        case .encodingFailed: "The converted image could not be saved."
        case .sourceChanged: "The source file changed during conversion. Try again with the current file."
        case .destinationExists: "A file with the converted name already exists. Save a copy or rename that file."
        case .previewChanged: "The preview was edited. Review the updated result and size, then save again."
        case .invalidPreview: "The preview is unavailable, damaged, or saved in a different format. Convert the image again."
        case .itemRemoved: "The item is no longer on this shelf."
        }
    }
}
