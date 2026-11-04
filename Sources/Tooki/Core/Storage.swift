import Foundation

enum StoragePaths {
    /// Shareable settings (`config.json`, `snippets.json`). Override with `TOOKI_CONFIG_DIR`.
    static var configDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["TOOKI_CONFIG_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/tooki")
    }

    /// Private machine data such as clipboard history. Never meant for dotfiles.
    static var dataDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Tooki")
    }
}

enum JSONFile {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func read(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    /// Writes through symlinks (instead of replacing them) so dotfile links stay intact.
    static func write(_ data: Data, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: target)
    }
}
