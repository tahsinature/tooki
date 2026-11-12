import Foundation

public enum SnippetGalleryExamples {
    public static let email = SnippetPackage(
        identity: .init(identifier: "tooki.email-address", version: "1.0.0", author: "Tooki"),
        name: "Email Address", description: "One snippet for your personal, work and other email addresses. Configure them once, then type @1, @2 or @3 followed by Space.", suggestedKeyword: "@",
        dynamic: DynamicSnippet(inputs: [.init(key: "account", label: "Account", kind: .choice, defaultValue: "1", choices: [.init("1", "Personal"), .init("2", "Work"), .init("3", "Other")])],
                                settings: [.init(key: "personal", label: "Personal email"), .init(key: "work", label: "Work email"), .init(key: "other", label: "Other email")],
                                entries: [.init("1", "{{config.personal}}"), .init("2", "{{config.work}}"), .init("3", "{{config.other}}")]))
    public static let slug = SnippetPackage(
        identity: .init(identifier: "tooki.slug", version: "1.0.0", author: "Tooki"),
        name: "URL Slug", description: "Turn a title into a clean URL slug. Type ;slug followed by a quoted title and finish with a semicolon, for example: ;slug \"My New Project\";", suggestedKeyword: ";slug",
        dynamic: DynamicSnippet(engine: .javascript, inputs: [.init(key: "title", label: "Title", defaultValue: "My New Project")],
                                script: "return input.normalize('NFKD').replace(/[\\u0300-\\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');", completion: .semicolon))
    public static let all = [email, slug]
}
