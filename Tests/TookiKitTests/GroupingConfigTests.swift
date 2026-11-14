import Foundation
import Testing
@testable import TookiKit

struct GroupingConfigTests {
    @Test func existingConfigsKeepGroupingEnabled() throws {
        for json in ["{}", #"{"clipboard":{},"snippets":{}}"#] {
            let config = try JSONDecoder().decode(TookiConfig.self, from: Data(json.utf8))
            #expect(config.clipboard.groupByDate)
            #expect(config.snippets.groupByDate)
        }
    }

    @Test func groupingPreferencesAreIndependentAndPersist() throws {
        var config = TookiConfig()
        config.clipboard.groupByDate = false
        let data = try JSONEncoder().encode(config)
        let saved = try JSONDecoder().decode(TookiConfig.self, from: data)
        #expect(!saved.clipboard.groupByDate)
        #expect(saved.snippets.groupByDate)

        config.clipboard.groupByDate = true
        config.snippets.groupByDate = false
        let updated = try JSONDecoder().decode(TookiConfig.self, from: JSONEncoder().encode(config))
        #expect(updated.clipboard.groupByDate)
        #expect(!updated.snippets.groupByDate)
    }
}
