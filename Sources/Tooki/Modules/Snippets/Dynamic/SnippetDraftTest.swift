import SwiftUI
import TookiKit

/// Testing is explicit. Merely opening an imported or edited script never executes it.
struct SnippetDraftTest: View {
    let snippet: Snippet
    @ViewState private var inputs: [String: String] = [:]
    @ViewState private var configuration: [String: String] = [:]
    @ViewState private var output: String?
    @ViewState private var error: String?
    @ViewState private var isRunning = false
    @ViewState private var generation = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let definition = snippet.dynamic {
                Text("Try inputs and inspect the output before saving. Test setup is not saved.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(definition.inputs) { field in
                    SnippetInputControl(field: field, value: fieldBinding(field, setup: false))
                }
                ForEach(definition.settings) { field in
                    SnippetInputControl(field: field, value: fieldBinding(field, setup: true))
                }
                Button(isRunning ? "Running…" : "Run Test", systemImage: "play") { run() }
                    .disabled(isRunning)
                if let error { Text(error).foregroundStyle(.orange) }
                if let output {
                    Text(output).font(.body.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(PanelTheme.tertiaryBackground, in: .rect(cornerRadius: 8))
                }
            }
        }
        .onDisappear { generation += 1 }
    }

    private func fieldBinding(_ field: SnippetInput, setup: Bool) -> Binding<String> {
        Binding(get: { (setup ? configuration : inputs)[field.key] ?? field.defaultValue }, set: {
            if setup { configuration[field.key] = $0 } else { inputs[field.key] = $0 }
            generation += 1; isRunning = false; output = nil; error = nil
        })
    }

    private func run() {
        var draft = snippet
        draft.configuration = configuration
        let version = generation
        isRunning = true
        Task {
            let result = await DynamicSnippetRunner.evaluate(draft, inputs: inputs)
            guard version == generation else { return }
            isRunning = false
            output = result.text
            error = result.error ?? (result.text == nil ? "No result. The typed input would be left unchanged." : nil)
        }
    }
}
