import ComposableArchitecture
import Foundation

/// Native panel fixtures use deterministic IDs and dates, just like the reducer tests.
@MainActor
func withSnippetTestDependencies<Result>(_ operation: () throws -> Result) rethrows -> Result {
    try withDependencies {
        $0.uuid = .incrementing
        $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
    } operation: {
        try operation()
    }
}
