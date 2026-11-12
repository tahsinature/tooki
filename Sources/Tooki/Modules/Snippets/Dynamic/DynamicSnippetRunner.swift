import Foundation
import TookiKit

enum DynamicSnippetRunner {
    static func evaluate(_ snippet: Snippet, inputs: [String: String]) async -> SnippetScriptWorker.Response {
        guard let definition = snippet.dynamic else { return .init(text: snippet.text) }
        do {
            try definition.validate()
            let values = try definition.values(inputs, for: definition.inputs)
            let config = try definition.values(snippet.configuration, for: definition.settings)
            if definition.engine == .lookup {
                return .init(text: definition.lookup(inputs: values, config: config))
            }
            return await SnippetScriptProcess.evaluate(.init(script: definition.script, inputs: values,
                                                             config: config, inputOrder: definition.inputs.map(\.key)))
        } catch { return .init(error: error.localizedDescription) }
    }
}
