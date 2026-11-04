import SwiftUI

/// Asks for the `{argument:name}` values of a snippet before pasting it.
struct ArgumentPromptView: View {
    let title: String
    let names: [String]
    /// Called with the values, or `nil` when cancelled.
    let onFinish: ([String: String]?) -> Void

    @State private var values: [String: String] = [:]
    @FocusState private var focusedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            ForEach(names, id: \.self) { name in
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.capitalized).font(.caption).foregroundStyle(.secondary)
                    TextField(name, text: binding(for: name))
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedName, equals: name)
                        .onSubmit { advance(from: name) }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { onFinish(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Paste") { onFinish(values) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear { focusedName = names.first }
    }

    private func binding(for name: String) -> Binding<String> {
        Binding(get: { values[name, default: ""] }, set: { values[name] = $0 })
    }

    private func advance(from name: String) {
        guard let index = names.firstIndex(of: name), index + 1 < names.count else {
            onFinish(values)
            return
        }
        focusedName = names[index + 1]
    }
}
