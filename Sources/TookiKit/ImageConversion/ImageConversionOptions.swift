import UniformTypeIdentifiers

public struct ImageConversionOptions: Sendable {
    public enum Format: String, CaseIterable, Sendable {
        case jpeg = "JPEG", png = "PNG", heif = "HEIF"

        public var fileExtension: String {
            switch self {
            case .jpeg: "jpg"
            case .png: "png"
            case .heif: "heic"
            }
        }

        var identifier: String {
            switch self {
            case .jpeg: UTType.jpeg.identifier
            case .png: UTType.png.identifier
            case .heif: UTType.heic.identifier
            }
        }
    }

    public enum Size: String, CaseIterable, Sendable {
        case actual = "Actual size", large = "Large", medium = "Medium", small = "Small"

        public var maxPixelSize: Int? {
            switch self {
            case .actual: nil
            case .large: 1920
            case .medium: 1280
            case .small: 640
            }
        }

        public var label: String {
            maxPixelSize.map { "\(rawValue) (\($0) px)" } ?? rawValue
        }
    }

    public enum Output: String, CaseIterable, Sendable {
        case replace = "Replace file", copy = "New copy"
    }

    public var format: Format = .jpeg
    public var size: Size = .actual
    public var preserveMetadata = true
    public var output: Output = .replace

    public init() {}
}
