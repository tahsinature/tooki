import SwiftUI
import TookiKit

struct SnippetsView: View {
    @Bindable var snippets: JSONDocument<[Snippet]>
    @ViewState private var selection: Snippet.ID?
    @ViewState private var filter = ""

    private var filtered: [Snippet] {
        guard !filter.isEmpty else { return snippets.value }
        return snippets.value.filter {
            $0.name.localizedCaseInsensitiveContains(filter) || $0.keyword.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form { PageHeader(page: .snippets) }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            editor
        }
    }

    private var editor: some View {
        HSplitView {
            snippetList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            Group {
                if let binding = binding(for: selection) {
                    SnippetEditor(snippet: binding, duplicateKeyword: hasDuplicateKeyword(binding.wrappedValue))
                } else {
                    ContentUnavailableView("No Snippet Selected", systemImage: "text.cursor")
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { selection = selection ?? snippets.value.first?.id }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            TextField("Filter snippets", text: $filter)
                .textFieldStyle(.roundedBorder)
                .padding(10)
            List(filtered, selection: $selection) { snippet in
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name.isEmpty ? "Untitled" : snippet.name)
                    if !snippet.keyword.isEmpty {
                        Text(snippet.keyword)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 2)
            }
            Divider()
            HStack {
                Button("Add Snippet", systemImage: "plus", action: addSnippet)
                Button("Delete Snippet", systemImage: "minus", action: deleteSelected)
                    .disabled(selection == nil)
                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(8)
        }
    }

    private func binding(for id: Snippet.ID?) -> Binding<Snippet>? {
        guard let id, snippets.value.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { snippets.value.first { $0.id == id } ?? Snippet(name: "", text: "") },
            set: { updated in
                if let index = snippets.value.firstIndex(where: { $0.id == id }) {
                    snippets.value[index] = updated
                }
            }
        )
    }

    private func hasDuplicateKeyword(_ snippet: Snippet) -> Bool {
        !snippet.keyword.isEmpty && snippets.value.contains { $0.id != snippet.id && $0.keyword == snippet.keyword }
    }

    private func addSnippet() {
        let snippet = Snippet(name: "New Snippet", text: "")
        snippets.value.append(snippet)
        filter = ""
        selection = snippet.id
    }

    private func deleteSelected() {
        guard let selection else { return }
        snippets.value.removeAll { $0.id == selection }
        self.selection = snippets.value.first?.id
    }
}

private struct SnippetEditor: View {
    @Binding var snippet: Snippet
    let duplicateKeyword: Bool

    @ViewState private var insertion = TextInsertion()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $snippet.name)
                .textFieldStyle(.plain)
                .font(.title2.bold())

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
