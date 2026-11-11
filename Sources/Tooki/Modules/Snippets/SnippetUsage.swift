import Foundation
import Observation
import TookiKit

/// How often and when each snippet was last pasted or copied. Kept on this Mac, outside the
/// config folder, so using a snippet never rewrites `snippets.json`.
@MainActor
@Observable
final class SnippetUsage {
    private(set) var history: LaunchHistory
    @ObservationIgnored private let fileURL = StoragePaths.dataDirectory.appending(path: "snippet-usage.json")

    init() {
        history = JSONFile.read(fileURL).flatMap { try? JSONFile.decoder.decode(LaunchHistory.self, from: $0) } ?? LaunchHistory()
    }

    func entry(for id: Snippet.ID) -> LaunchHistory.Entry? {
        history.entries[id.uuidString]
    }

    func record(_ id: Snippet.ID) {
        history.record(id.uuidString)
        guard let data = try? JSONFile.encoder.encode(history) else { return }
        try? JSONFile.write(data, to: fileURL)
    }
}
