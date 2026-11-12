import Foundation
import TookiKit

/// A website can distribute the same portable file through a reviewed Tooki import link.
enum SnippetRemoteImport {
    static func load(_ url: URL) async throws -> SnippetPackage {
        guard url.scheme == "https" else { throw SnippetDefinitionError("Package links must use HTTPS.") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration, delegate: HTTPSRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(from: url)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
              response.url?.scheme == "https" else { throw SnippetDefinitionError("The package could not be downloaded.") }
        guard response.expectedContentLength <= 262_144 else { throw SnippetDefinitionError("Packages must be smaller than 256 KB.") }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 262_144 else { throw SnippetDefinitionError("Packages must be smaller than 256 KB.") }
            data.append(byte)
        }
        let package = try JSONDecoder().decode(SnippetPackage.self, from: data)
        try package.validate()
        return package
    }
}

private final class HTTPSRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
}
