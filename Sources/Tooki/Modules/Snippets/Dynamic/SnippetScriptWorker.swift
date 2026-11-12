import Foundation
import JavaScriptCore
import TookiKit

/// Private subprocess protocol. No Objective-C objects or native functions are exported to JS.
enum SnippetScriptWorker {
    struct Request: Codable, Sendable {
        let script: String
        let inputs: [String: String]
        let config: [String: String]
        let inputOrder: [String]
    }
    struct Response: Codable, Sendable {
        var text: String?
        var error: String?
    }

    static func run() -> Int32 {
        do {
            let data = FileHandle.standardInput.readData(ofLength: 262_145)
            guard data.count <= 262_144 else { throw SnippetDefinitionError("Script request is too large.") }
            let request = try JSONDecoder().decode(Request.self, from: data)
            guard let context = JSContext() else { throw SnippetDefinitionError("JavaScript could not start.") }
            // Pass JSON data as JS literals, never interpolate input into executable code.
            let encoder = JSONEncoder()
            let inputs = String(decoding: try encoder.encode(request.inputs), as: UTF8.self)
            let config = String(decoding: try encoder.encode(request.config), as: UTF8.self)
            let input = request.inputOrder.first.flatMap { request.inputs[$0] } ?? ""
            let first = String(decoding: try encoder.encode(input), as: UTF8.self)
            let source = """
            (function(input, inputs, config, now) {
              "use strict";
              \(request.script)
            })(\(first), Object.freeze(\(inputs)), Object.freeze(\(config)), new Date())
            """
            let value = context.evaluateScript(source)
            if let exception = context.exception { throw SnippetDefinitionError(exception.toString() ?? "JavaScript failed.") }
            let result: Response
            if value == nil || value!.isNull || value!.isUndefined {
                result = Response()
            } else {
                guard value!.isString else { throw SnippetDefinitionError("Return a string, or null to leave the input unchanged.") }
                let text = value!.toString() ?? ""
                guard text.utf8.count <= 100_000 else { throw SnippetDefinitionError("Output must be smaller than 100 KB.") }
                result = Response(text: text)
            }
            FileHandle.standardOutput.write(try encoder.encode(result))
            return 0
        } catch {
            let response = Response(error: error.localizedDescription)
            if let data = try? JSONEncoder().encode(response) { FileHandle.standardOutput.write(data) }
            return 1
        }
    }
}
