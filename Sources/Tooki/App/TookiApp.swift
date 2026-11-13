import SwiftUI

struct TookiApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        @Bindable var app = delegate.app
        MenuBarExtra {
            MenuBarMenu(app: delegate.app)
        } label: {
            MenuBarLabel()
        }
        MenuBarExtra("Keep Awake", systemImage: "cup.and.saucer.fill", isInserted: $app.isCoffeeIconInserted) {
            KeepAwakeMenu(keepAwake: app.keepAwake) { app.showSettings(.keepAwake) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let app = AppController()

    /// Registered before launch finishes so a `tooki://` link that launched Tooki isn't lost.
    @MainActor
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @MainActor @objc
    private func handleURLEvent(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text)
        else { return }
        app.open(url)
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        TerminationSignals.install()
        Task {
            await SingleInstance.replaceOlderCopies()
            app.start()
        }
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        app.shutdown()
    }

    /// Clicking Tooki in Finder or Spotlight again opens settings.
    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        app.showSettings()
        return false
    }
}
