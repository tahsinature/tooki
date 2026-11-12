import Foundation
import Testing
@testable import TookiKit

struct SnippetMigrationPlaceholderTests {
    @Test func dateTimeUsesTheCapturedTimeAndSystemFormatting() {
        let now = Date(timeIntervalSince1970: 1_793_793_600)
        let result = PlaceholderExpander.expand("{datetime}", context: ExpansionContext(now: now))
        #expect(result.text == now.formatted(date: .abbreviated, time: .shortened))
        let custom = PlaceholderExpander.expand("{datetime:yyyy}", context: ExpansionContext(now: now))
        #expect(custom.text == "2026")
    }

    @Test func uuidIsGeneratedOnEachExpansion() {
        let first = PlaceholderExpander.expand("{uuid}", context: ExpansionContext()).text
        let second = PlaceholderExpander.expand("{uuid}", context: ExpansionContext()).text
        #expect(UUID(uuidString: first) != nil)
        #expect(UUID(uuidString: second) != nil)
        #expect(first != second)
        #expect(first == first.uppercased())
    }

    @Test func randomEmailKeepsTheLowercaseUUIDAndDomain() {
        let result = PlaceholderExpander.expand("{uuid:lowercase}@example.com", context: ExpansionContext()).text
        let uuid = String(result.dropLast("@example.com".count))
        #expect(UUID(uuidString: uuid) != nil)
        #expect(uuid == uuid.lowercased())
        #expect(result.hasSuffix("@example.com"))
    }

    @Test func unknownUUIDOptionsAndCodeRemainUnchanged() {
        let text = "{uuid:unsupported} { console.log(value); }"
        #expect(PlaceholderExpander.expand(text, context: ExpansionContext()).text == text)
    }
}
