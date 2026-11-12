import Foundation

public struct DynamicSnippet: Codable, Equatable, Sendable {
    public enum Engine: String, Codable, CaseIterable, Sendable { case lookup, javascript }
    public enum Completion: String, Codable, CaseIterable, Sendable {
        case space, semicolon
        public var character: Character { self == .space ? " " : ";" }
        public var label: String { self == .space ? "Space" : ";" }
    }
    public var engine: Engine
    public var inputs: [SnippetInput]
    public var settings: [SnippetInput]
    public var entries: [SnippetLookupEntry]
    /// Function body. Receives `input`, `inputs`, `config`, and `now` as ordinary JS values.
    public var script: String
    public var completion: Completion

    public init(engine: Engine = .lookup, inputs: [SnippetInput] = [], settings: [SnippetInput] = [], entries: [SnippetLookupEntry] = [], script: String = "", completion: Completion = .space) {
        self.engine = engine; self.inputs = inputs; self.settings = settings
        self.entries = entries; self.script = script; self.completion = completion
    }

    public func values(_ supplied: [String: String], for fields: [SnippetInput]) throws -> [String: String] {
        var values: [String: String] = [:]
        for field in fields {
            let value = supplied[field.key] ?? field.defaultValue
            if field.required && value.isEmpty { throw SnippetDefinitionError("Enter \(field.label).") }
            if !value.isEmpty {
                switch field.kind {
                case .choice:
                    guard field.choices.contains(where: { $0.value == value }) else { throw SnippetDefinitionError("Choose a valid \(field.label).") }
                case .number:
                    guard let number = Double(value), number.isFinite else { throw SnippetDefinitionError("\(field.label) must be a number.") }
                case .date:
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.isLenient = false
                    guard let date = formatter.date(from: value), formatter.string(from: date) == value else { throw SnippetDefinitionError("\(field.label) must use YYYY-MM-DD.") }
                case .text: break
                }
            }
            values[field.key] = value
        }
        return values
    }

    public func validate() throws {
        for fields in [inputs, settings] {
            guard fields.count <= 12 else { throw SnippetDefinitionError("Use at most 12 fields.") }
            var keys = Set<String>()
            for field in fields {
                guard field.key.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil,
                      keys.insert(field.key).inserted, !field.label.isEmpty else {
                    throw SnippetDefinitionError("Fields need unique keys and a label. Keys use letters, numbers and underscores.")
                }
                if field.kind == .choice {
                    guard !field.choices.isEmpty, Set(field.choices.map(\.value)).count == field.choices.count,
                          field.choices.allSatisfy({ !$0.value.isEmpty && !$0.label.isEmpty }) else {
                        throw SnippetDefinitionError("Choices need unique values and labels.")
                    }
                }
            }
        }
        if engine == .lookup {
            guard inputs.count == 1, !entries.isEmpty, Set(entries.map(\.input)).count == entries.count else {
                throw SnippetDefinitionError("A lookup needs one input and unique lookup keys.")
            }
        } else if script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SnippetDefinitionError("Write a JavaScript function body.")
        }
    }

    public func lookup(inputs: [String: String], config: [String: String]) -> String? {
        guard let key = self.inputs.first?.key, let value = inputs[key],
              var output = entries.first(where: { $0.input == value })?.output else { return nil }
        for setting in settings {
            output = output.replacingOccurrences(of: "{{config.\(setting.key)}}", with: config[setting.key] ?? "")
        }
        return output
    }
}

public struct SnippetDefinitionError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
