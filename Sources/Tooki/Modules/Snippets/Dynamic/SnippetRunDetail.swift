import SwiftUI
import TookiKit

/// Dynamic snippets expose their declared inputs and output inside the existing Detail Pane.
struct SnippetRunDetail: View {
    @Bindable var model: SnippetPanelModel
    let snippet: Snippet
    let definition: DynamicSnippet
    let onRun: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "function").foregroundStyle(.tint)
                    Text(snippet.name).font(.headline)
                    Spacer()
                    Text(definition.engine == .lookup ? "LOOKUP" : "JAVASCRIPT")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                if !snippet.keyword.isEmpty {
                    Label("Type \(snippet.keyword) followed by your input, then \(definition.completion.label).", systemImage: "keyboard")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(definition.inputs) { field in
                    SnippetInputControl(field: field, value: inputBinding(field))
                }
                if !definition.settings.isEmpty {
                    DisclosureGroup("Your setup") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved on this Mac. Your values are excluded when you share this snippet.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            ForEach(definition.settings) { field in
                                SnippetInputControl(field: field, value: configBinding(field))
                            }
                            Button("Save Setup") { model.saveDynamicConfiguration() }
                        }.padding(.top, 8)
                    }
                }
                HStack {
                    Text("OUTPUT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if model.isRunning { ProgressView().controlSize(.small) }
                    Button("Preview", systemImage: "play") { model.previewDynamic() }
                        .disabled(model.isRunning)
                }
                Group {
                    if let error = model.dynamicError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if let output = model.dynamicOutput {
                        Text(output.isEmpty ? "Empty output" : output)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Choose your inputs, then preview or press Return to copy the result.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .padding(12)
                .background(PanelTheme.tertiaryBackground, in: .rect(cornerRadius: 10))
                Text("Scripts run only when you choose Preview, Copy or Paste. They have no file, network or clipboard access.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .buttonStyle(InteractionButtonStyle(restingFill: Color.primary.opacity(0.06), horizontalPadding: 8, verticalPadding: 5))
        .onSubmit(onRun)
        .onChange(of: snippet.id, initial: true) { model.resetDynamicRun() }
    }

    private func inputBinding(_ field: SnippetInput) -> Binding<String> {
        Binding(get: { model.dynamicInputs[field.key] ?? field.defaultValue }, set: {
            model.dynamicInputs[field.key] = $0
            model.invalidateDynamicOutput()
        })
    }
    private func configBinding(_ field: SnippetInput) -> Binding<String> {
        Binding(get: { model.dynamicConfiguration[field.key] ?? field.defaultValue }, set: {
            model.dynamicConfiguration[field.key] = $0
            model.invalidateDynamicOutput()
        })
    }
}
