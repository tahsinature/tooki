import Foundation

/// Input definitions are shared by keyword arguments, the runner UI and portable packages.
public struct SnippetInput: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case text, number, choice, date }
    public var key: String
    public var label: String
    public var kind: Kind
    public var defaultValue: String
    /// For choices, the first part is the typed value, followed by an optional display label.
    public var choices: [SnippetChoice]
    public var required: Bool
    public var id: String { key }

    public init(key: String, label: String, kind: Kind = .text, defaultValue: String = "", choices: [SnippetChoice] = [], required: Bool = true) {
        self.key = key; self.label = label; self.kind = kind
        self.defaultValue = defaultValue; self.choices = choices; self.required = required
    }
}

public struct SnippetChoice: Codable, Equatable, Sendable {
    public var value: String
    public var label: String
    public init(_ value: String, _ label: String) { self.value = value; self.label = label }
}

public struct SnippetLookupEntry: Codable, Equatable, Sendable {
    public var input: String
    public var output: String
    public init(_ input: String, _ output: String) { self.input = input; self.output = output }
}

