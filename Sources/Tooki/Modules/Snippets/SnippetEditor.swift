import SwiftUI
import TookiKit

/// Edits one snippet: name, keyword, collection and the text it expands to.
struct SnippetEditor: View {
    @Binding var snippet: Snippet
    let duplicateKeyword: Bool
    let onDelete: () -> Void

    @ViewState private var insertion = TextInsertion()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Name", text: $snippet.name)
                    .textFieldStyle(.plain)
                    .font(.title2.bold())
                Button("Delete Snippet", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Delete Snippet")
            }

            HStack(spacing: 12) {
                field("Keyword") {
                    TextField(";keyword", text: $snippet.keyword).font(.body.monospaced())
                }
                field("Collection") {
                    TextField("Work", text: $snippet.collection)
                }
            }
            if duplicateKeyword {
                Label("Another snippet uses this keyword.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            SnippetTextEditor(text: $snippet.text, insertion: insertion)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))

            PlaceholderMenu(insert: insertion.insert)
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
