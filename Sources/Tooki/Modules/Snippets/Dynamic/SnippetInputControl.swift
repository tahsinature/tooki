import SwiftUI
import TookiKit

/// The same declared field is used for run inputs and personal setup.
struct SnippetInputControl: View {
    let field: SnippetInput
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(field.label + (field.required ? "" : " (optional)"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            if field.kind == .choice {
                Picker(field.label, selection: $value) {
                    Text("Choose…").tag("")
                    ForEach(field.choices, id: \.value) { choice in
                        Text("\(choice.label) · \(choice.value)").tag(choice.value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            } else {
                TextField(field.kind == .date ? "YYYY-MM-DD" : field.label, text: $value)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(field.label)
            }
        }
    }
}
