import SwiftUI
import TookiKit

/// Imports and updates are reviewable, and never execute a package's code.
struct SnippetPackageReview: View {
    let package: SnippetPackage
    @Bindable var snippets: JSONDocument<[Snippet]>
    @ViewState private var keyword = ""
    @ViewState private var configuration: [String: String] = [:]
    @ViewState private var error: String?
    @ViewState private var installed = false

    private var existing: Snippet? { snippets.value.first { $0.package?.identifier == package.id } }
    private var conflict: Snippet? {
        guard !keyword.isEmpty else { return nil }
        return snippets.value.first { $0.keyword == keyword && $0.id != existing?.id }
    }

    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(package.dynamic == nil ? "TEXT SNIPPET" : "DYNAMIC SNIPPET", systemImage: package.dynamic == nil ? "text.quote" : "function")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                Text(package.name).font(.title2.bold())
                Text("\(package.identity.author) · Version \(package.identity.version)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(package.description).fixedSize(horizontal: false, vertical: true)
                Label("No external capabilities", systemImage: "checkmark.shield")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Imports do not run code. JavaScript runs in isolation when you explicitly run the snippet.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyword").font(.headline)
                    TextField("Leave blank for panel use only", text: $keyword).textFieldStyle(.roundedBorder)
                    if let conflict {
                        Text("Already used by “\(conflict.name)”. Choose another keyword, or leave it blank.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if let definition = package.dynamic {
                    if !definition.settings.isEmpty {
                        Text("Your setup").font(.headline)
                        Text("These values stay on your Mac and are excluded when sharing.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(definition.settings) { field in
                            SnippetInputControl(field: field, value: Binding(get: { configuration[field.key] ?? field.defaultValue }, set: { configuration[field.key] = $0 }))
                        }
                    }
                    DisclosureGroup("Inspect logic and inputs") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(definition.inputs) { field in
                                Text("\(field.label) · \(field.kind.rawValue) · \(field.key)").font(.subheadline)
                            }
                            Text(definition.engine == .javascript ? definition.script : definition.entries.map { "\($0.input) → \($0.output)" }.joined(separator: "\n"))
                                .font(.body.monospaced()).textSelection(.enabled)
                        }.padding(.top, 10)
                    }
                } else {
                    Text(package.text).font(.body.monospaced()).textSelection(.enabled)
                }
                if let existing {
                    Text("Updates “\(existing.name)” (\(existing.package?.version ?? "")); your collection, pin and personal setup are preserved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24)
        }
        Divider()
        HStack(spacing: 12) {
            Text(error ?? (installed ? "Ready in your Snippets panel." : "Review and configure before adding."))
                .font(.subheadline).foregroundStyle(error == nil ? Color.secondary : Color.orange)
            Spacer(minLength: 8)
            Button(installed ? "Installed" : (existing == nil ? "Add to Snippets" : "Update Snippet"), systemImage: installed ? "checkmark" : "plus") { install() }
                .buttonStyle(.borderedProminent)
                .disabled(conflict != nil || installed)
        }.padding(16)
        }
        .onChange(of: package, initial: true) {
            keyword = existing?.keyword ?? package.suggestedKeyword
            configuration = existing?.configuration ?? [:]
            error = nil; installed = false
        }
    }

    private func install() {
        guard conflict == nil else { return }
        do {
            let snippet = try package.installing(over: existing, keyword: keyword, configuration: configuration)
            if let index = snippets.value.firstIndex(where: { $0.id == snippet.id }) { snippets.value[index] = snippet }
            else { snippets.value.append(snippet) }
            installed = true
        } catch { self.error = error.localizedDescription }
    }
}
