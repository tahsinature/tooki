import Foundation
import Observation
import TookiKit

@MainActor
@Observable
final class SnippetGalleryState {
    var isPresented = false
    var importedPackage: SnippetPackage?
    var error: String?
    var isLoading = false
    private var requestGeneration = 0

    func importRemote(_ url: URL) {
        requestGeneration += 1
        let generation = requestGeneration
        isPresented = true
        isLoading = true
        error = nil
        Task {
            do {
                let package = try await SnippetRemoteImport.load(url)
                guard generation == requestGeneration else { return }
                importedPackage = package
            } catch {
                guard generation == requestGeneration else { return }
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    func importFile(_ url: URL) {
        requestGeneration += 1
        isLoading = false
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 262_144 else { throw SnippetDefinitionError("Packages must be smaller than 256 KB.") }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 262_144 else { throw SnippetDefinitionError("Packages must be smaller than 256 KB.") }
            let package = try JSONDecoder().decode(SnippetPackage.self, from: data)
            try package.validate()
            importedPackage = package
            error = nil
            isPresented = true
        } catch { self.error = error.localizedDescription; isPresented = true }
    }
}
