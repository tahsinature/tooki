import Foundation
import TookiKit

/// A fresh process per run makes the time limit enforceable, even for an infinite JS loop.
enum SnippetScriptProcess {
    static func evaluate(_ request: SnippetScriptWorker.Request) async -> SnippetScriptWorker.Response {
        await Task.detached(priority: .userInitiated) { execute(request) }.value
    }

    private static func execute(_ request: SnippetScriptWorker.Request) -> SnippetScriptWorker.Response {
        let process = Process()
        let input = Pipe(); let output = Pipe()
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["--snippet-worker"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // The child receives no inherited secrets from the shell environment.
        process.environment = ["LANG": "en_US.UTF-8"]
        let timeout = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        do {
            let data = try JSONEncoder().encode(request)
            guard data.count <= 262_144 else { throw SnippetDefinitionError("Script request is too large.") }
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: timeout)
            defer { timeout.cancel() }
            try input.fileHandleForWriting.write(contentsOf: data)
            try input.fileHandleForWriting.close()
            let result = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let response = try? JSONDecoder().decode(SnippetScriptWorker.Response.self, from: result) { return response }
            return .init(error: "The script timed out or stopped unexpectedly. The time limit is 2 seconds.")
        } catch {
            if process.isRunning { process.terminate() }
            return .init(error: error.localizedDescription)
        }
    }
}
