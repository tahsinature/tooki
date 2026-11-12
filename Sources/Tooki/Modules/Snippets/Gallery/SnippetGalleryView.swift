import AppKit
import SwiftUI
import TookiKit
import UniformTypeIdentifiers

struct SnippetGalleryView: View {
    @Bindable var state: SnippetGalleryState
    @Bindable var snippets: JSONDocument<[Snippet]>
    @Environment(\.dismiss) private var dismiss
    @ViewState private var selectedID = SnippetGalleryExamples.email.id
    @ViewState private var isImporting = false

    private var packages: [SnippetPackage] {
        let imported = state.importedPackage.map { [$0] } ?? []
        return imported + SnippetGalleryExamples.all.filter { $0.id != state.importedPackage?.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2").foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Snippet Gallery").font(.headline)
                    Text("Reusable ideas. Your own inputs and setup.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Import Package…", systemImage: "square.and.arrow.down") { isImporting = true }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STARTER COLLECTION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(packages) { package in
                            Button { selectedID = package.id } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(package.name, systemImage: package.dynamic?.engine == .javascript ? "curlybraces" : "list.bullet.rectangle")
                                        .font(.headline)
                                    Text(package.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                                    Text(package.dynamic?.engine == .javascript ? "JavaScript" : "Lookup").font(.caption).foregroundStyle(.tint)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                            }
                            .buttonStyle(InteractionButtonStyle(restingFill: selectedID == package.id ? PanelTheme.selectedBackground : PanelTheme.tertiaryBackground, radius: 10))
                        }
                        Text("Share .tookisnippet packages with other people or distribute them from a website.")
                            .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                    }.padding(16)
                }.frame(width: 260)
                Divider()
                if let package = packages.first(where: { $0.id == selectedID }) {
                    SnippetPackageReview(package: package, snippets: snippets).id(package.id)
                }
            }
            if state.isLoading { ProgressView("Downloading package…").controlSize(.small).padding(12) }
            if let error = state.error {
                Text(error).foregroundStyle(.orange).font(.subheadline).padding(12)
            }
        }
        .frame(width: 820, height: 600)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [SnippetPackageExporter.contentType, .json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                state.importFile(url)
                if let package = state.importedPackage { selectedID = package.id }
            case .failure(let error): state.error = error.localizedDescription
            }
        }
        .onAppear { if let package = state.importedPackage { selectedID = package.id } }
        .onChange(of: state.importedPackage) { if let package = state.importedPackage { selectedID = package.id } }
    }
}
