import AppKit

/// Turns `kill` (SIGTERM) and Ctrl+C (SIGINT) into a normal quit, so cleanup in
/// `applicationWillTerminate` runs and Caps Lock is never left remapped.
@MainActor
enum TerminationSignals {
    private static var sources: [DispatchSourceSignal] = []

    static func install() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            sources.append(source)
        }
    }
}
