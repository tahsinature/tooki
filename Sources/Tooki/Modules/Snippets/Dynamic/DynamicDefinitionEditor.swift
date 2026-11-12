import SwiftUI
import TookiKit

struct DynamicDefinitionEditor: View {
    @Binding var definition: DynamicSnippet
    let snippet: Snippet
    @ViewState private var tab = "Logic"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Section", selection: $tab) {
                ForEach(["Logic", "Inputs", "Setup", "Test"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Editor section")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tab == "Test" {
                        SnippetDraftTest(snippet: snippet)
                    } else if tab == "Inputs" {
                        SnippetFieldEditor(fields: $definition.inputs)
                    } else if tab == "Setup" {
                        SnippetFieldEditor(fields: $definition.settings, isConfiguration: true)
                    } else {
                        logic
                    }
                }.padding(2)
            }
        }
    }

    private var logic: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Engine", selection: $definition.engine) {
                Text("Lookup table").tag(DynamicSnippet.Engine.lookup)
                Text("JavaScript").tag(DynamicSnippet.Engine.javascript)
            }
            if definition.engine == .lookup {
                Text("Match the first input to an output. Use {{config.key}} to insert a personal setup value.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(definition.entries.indices, id: \.self) { index in
                    HStack {
                        TextField("Input", text: $definition.entries[index].input).frame(width: 70)
                        TextField("Output", text: $definition.entries[index].output)
                        Button("Remove mapping", systemImage: "minus.circle") { definition.entries.remove(at: index) }
                            .labelStyle(.iconOnly)
                    }.textFieldStyle(.roundedBorder)
                }
                Button("Add Mapping", systemImage: "plus") { definition.entries.append(.init("", "")) }
            } else {
                Text("Return text, or null for no result. Use input, inputs.key, config.key and now (a Date).")
                    .font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $definition.script)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(PanelTheme.tertiaryBackground, in: .rect(cornerRadius: 8))
                Text("JavaScript only. No shell commands, file access, network or clipboard. Two-second limit.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Expand after", selection: $definition.completion) {
                ForEach(DynamicSnippet.Completion.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
    }
}
