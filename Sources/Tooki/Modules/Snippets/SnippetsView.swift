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
        VStack(alignment: .leading, spacing: 16) {
            InlinePageHeader(page: .snippets)
            HStack(spacing: 16) {
                snippetList
                    .frame(width: 260)
                    .groupedCard()
                selectedEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .groupedCard()
            }
        }
        .padding(20)
        .onAppear { selection = selection ?? snippets.value.first?.id }
    }

    @ViewBuilder
    private var selectedEditor: some View {
        if let binding = binding(for: selection) {
            SnippetEditor(
                snippet: binding,
                duplicateKeyword: hasDuplicateKeyword(binding.wrappedValue),
                onDelete: deleteSelected
            )
        } else {
            ContentUnavailableView("No Snippet Selected", systemImage: "text.cursor")
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Filter", text: $filter)
                    .textFieldStyle(.roundedBorder)
                Button("New Snippet", systemImage: "plus", action: addSnippet)
                    .labelStyle(.iconOnly)
                    .help("New Snippet")
            }
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
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(snippet.id) }
                }
            }
            .scrollContentBackground(.hidden)
            .onDeleteCommand(perform: deleteSelected)
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
        if let selection { delete(selection) }
    }

    private func delete(_ id: Snippet.ID) {
        snippets.value.removeAll { $0.id == id }
        if selection == id { selection = snippets.value.first?.id }
    }
}
