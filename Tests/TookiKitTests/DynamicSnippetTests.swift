import Foundation
import Testing
@testable import TookiKit

@Suite struct DynamicSnippetTests {
    private var email: Snippet {
        Snippet(name: "Emails", keyword: "@", text: "", dynamic: SnippetGalleryExamples.email.dynamic,
                configuration: ["personal": "one@mail.com", "work": "two@mail.com", "other": "three@mail.com"])
    }

    @Test func completedLookupConsumesThePrefixInputAndTerminator() throws {
        let match = try #require(DynamicKeywordMatcher.match(typed: "hello @2 ", in: [email]))
        #expect(match.length == 3)
        #expect(match.inputs == ["account": "2"])
        #expect(match.snippet.dynamic?.lookup(inputs: match.inputs, config: email.configuration) == "two@mail.com")
        #expect(DynamicKeywordMatcher.match(typed: "@2", in: [email]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "@", in: [email]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "@ ", in: [email]) == nil)
        #expect(KeywordMatcher.match(typed: "@", in: [email]) == nil)
    }

    @Test func unknownInputsAndEmailAddressInteriorsStayUntouched() {
        #expect(DynamicKeywordMatcher.match(typed: "@9 ", in: [email]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "name@2 ", in: [email]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "name_@2 ", in: [email]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "@@2 ", in: [email]) == nil)
    }

    @Test func multiDigitAliasesAreNotExpandedEarly() {
        var snippet = email
        snippet.dynamic?.inputs[0].choices.append(.init("10", "Tenth"))
        snippet.dynamic?.entries.append(.init("10", "tenth@mail.com"))
        #expect(DynamicKeywordMatcher.match(typed: "@1", in: [snippet]) == nil)
        #expect(DynamicKeywordMatcher.match(typed: "@10 ", in: [snippet])?.inputs["account"] == "10")
    }

    @Test func quotesAreParsedWithoutShellInterpretation() {
        #expect(DynamicKeywordMatcher.parseArguments(#""hello world" 3"#) == ["hello world", "3"])
        #expect(DynamicKeywordMatcher.parseArguments(#""$(whoami)""#) == ["$(whoami)"])
        #expect(DynamicKeywordMatcher.parseArguments("\"unfinished") == nil)
        #expect(DynamicKeywordMatcher.parseArguments("unfinished\\") == nil)
        let slug = Snippet(name: "Slug", keyword: ";slug", text: "", dynamic: SnippetGalleryExamples.slug.dynamic)
        #expect(DynamicKeywordMatcher.match(typed: #";slug "My New Project";"#, in: [slug])?.inputs["title"] == "My New Project")
    }

    @Test func inputValidationCatchesInvalidNumbersDatesAndChoices() throws {
        let definition = DynamicSnippet()
        #expect(throws: SnippetDefinitionError.self) { try definition.values(["count": "NaN"], for: [.init(key: "count", label: "Count", kind: .number)]) }
        #expect(throws: SnippetDefinitionError.self) { try definition.values(["day": "2026-02-30"], for: [.init(key: "day", label: "Day", kind: .date)]) }
        #expect(try definition.values(["day": "2026-11-12"], for: [.init(key: "day", label: "Day", kind: .date)]) == ["day": "2026-11-12"])
        #expect(throws: SnippetDefinitionError.self) { try email.dynamic!.values(["account": "9"], for: email.dynamic!.inputs) }
    }

    @Test func packageRoundTripExcludesPersonalValuesAndPreservesLocalUpdateState() throws {
        var original = email
        original.isPinned = true
        original.collection = "Private"
        original.dynamic?.settings[0].defaultValue = "secret@mail.com"
        let package = SnippetPackage(exporting: original, author: "Example", description: "Choose an email")
        let data = try JSONEncoder().encode(package)
        let string = String(decoding: data, as: UTF8.self)
        #expect(!string.contains("secret@mail.com"))
        #expect(!string.contains("one@mail.com"))
        let decoded = try JSONDecoder().decode(SnippetPackage.self, from: data)
        let updated = try decoded.installing(over: original, keyword: "@@", configuration: original.configuration)
        #expect(updated.id == original.id)
        #expect(updated.isPinned)
        #expect(updated.collection == "Private")
        #expect(updated.configuration == original.configuration)
        #expect(updated.keyword == "@@")
        #expect(updated.package?.identifier == package.id)
    }

    @Test func packagesRejectUnsupportedCapabilitiesVersionsAndDuplicateFields() {
        var package = SnippetGalleryExamples.slug
        package.capabilities = ["shell"]
        #expect(throws: SnippetDefinitionError.self) { try package.validate() }
        package.capabilities = []
        package.formatVersion = 2
        #expect(throws: SnippetDefinitionError.self) { try package.validate() }
        package.formatVersion = 1
        let duplicate = package.dynamic!.inputs[0]
        package.dynamic?.inputs.append(duplicate)
        #expect(throws: SnippetDefinitionError.self) { try package.validate() }
    }

    @Test func legacySnippetDecodingAndDynamicRoundTripStayCompatible() throws {
        let legacy = try JSONDecoder().decode(Snippet.self, from: Data(#"{"name":"Old","keyword":";old","text":"Hello"}"#.utf8))
        #expect(legacy.dynamic == nil)
        #expect(legacy.configuration.isEmpty)
        #expect(KeywordMatcher.match(typed: ";old", in: [legacy]) == legacy)
        let original = email
        let roundTrip = try JSONDecoder().decode(Snippet.self, from: JSONEncoder().encode(original))
        #expect(roundTrip == original)
    }
}
