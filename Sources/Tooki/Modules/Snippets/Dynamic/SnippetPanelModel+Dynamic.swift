import Foundation
import TookiKit

extension SnippetPanelModel {
    func resetDynamicRun() {
        dynamicInputs = [:]
        dynamicConfiguration = selectedSnippet?.configuration ?? [:]
        invalidateDynamicOutput()
    }

    func invalidateDynamicOutput() {
        runGeneration += 1
        dynamicOutput = nil
        dynamicError = nil
        isRunning = false
    }

    func saveDynamicConfiguration() {
        guard let snippet = selectedSnippet, let definition = snippet.dynamic,
              let index = snippets.value.firstIndex(where: { $0.id == snippet.id }) else { return }
        do {
            let values = try definition.values(dynamicConfiguration, for: definition.settings)
            snippets.value[index].configuration = values
            dynamicError = nil
        } catch { dynamicError = error.localizedDescription }
    }

    func previewDynamic() {
        Task { _ = await resolveDynamic() }
    }

    /// Selection/input edits invalidate an in-flight run, so stale output never gets copied.
    func resolveDynamic() async -> String? {
        guard var snippet = selectedSnippet, snippet.dynamic != nil, !isRunning else { return nil }
        snippet.configuration = dynamicConfiguration
        let generation = runGeneration
        isRunning = true
        let response = await DynamicSnippetRunner.evaluate(snippet, inputs: dynamicInputs)
        guard generation == runGeneration, selectedSnippet?.id == snippet.id else { return nil }
        isRunning = false
        dynamicOutput = response.text
        dynamicError = response.error ?? (response.text == nil ? "No result for these inputs. Your text was left unchanged." : nil)
        return response.error == nil ? response.text : nil
    }
}
