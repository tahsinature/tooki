import Foundation

struct ImageFileFingerprint: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let byteCount: UInt64
    let modified: Date

    init(url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let modified = attributes[.modificationDate] as? Date
        else { throw ImageConversionError.unsupported }
        device = (attributes[.systemNumber] as? NSNumber)?.uint64Value ?? 0
        inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        byteCount = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        self.modified = modified
    }
}
