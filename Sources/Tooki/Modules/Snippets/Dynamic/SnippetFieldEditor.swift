import SwiftUI
import TookiKit

/// Authors declare fields once. Tooki builds the run and setup controls from this definition.
struct SnippetFieldEditor: View {
    @Binding var fields: [SnippetInput]
    var isConfiguration = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isConfiguration ? "Personal setup is saved locally and excluded from exported packages." : "Inputs are passed in this order when typed. Choice values are the short aliases people remember.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(fields.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Key", text: $fields[index].key)
                        TextField("Label", text: $fields[index].label)
                        Button("Remove", systemImage: "minus.circle") { fields.remove(at: index) }
                            .labelStyle(.iconOnly)
                    }
                    HStack {
                        Picker("Type", selection: $fields[index].kind) {
                            ForEach(SnippetInput.Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        Toggle("Required", isOn: $fields[index].required)
                    }
                    if !isConfiguration {
                        TextField("Default value (optional)", text: $fields[index].defaultValue)
                    }
                    if fields[index].kind == .choice {
                        ForEach(fields[index].choices.indices, id: \.self) { choice in
                            HStack {
                                TextField("Value", text: $fields[index].choices[choice].value)
                                TextField("Display label", text: $fields[index].choices[choice].label)
                                Button("Remove choice", systemImage: "minus.circle") { fields[index].choices.remove(at: choice) }
                                    .labelStyle(.iconOnly)
                            }
                        }
                        Button("Add Choice", systemImage: "plus") { fields[index].choices.append(.init("", "")) }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .background(PanelTheme.tertiaryBackground, in: .rect(cornerRadius: 10))
            }
            Button("Add Field", systemImage: "plus") {
                fields.append(SnippetInput(key: "field\(fields.count + 1)", label: "New field"))
            }
            .disabled(fields.count >= 12)
        }
    }
}
