import SwiftUI

@main
struct TookiApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(app: delegate.app)
        } label: {
            if delegate.app.keepAwake.isActive {
                Image(systemName: "cup.and.saucer.fill")
            } else {
                Image(nsImage: MenuBarIcon.image)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let app = AppController()

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

struct MenuBarMenu: View {
    let app: AppController

    var body: some View {
        Button("Search…") { app.toggleSearch(.everything) }
        Button("Clipboard History…") { app.toggleClipboard() }
        Divider()
        Text("Keep Awake: \(app.keepAwake.statusText)")
        if app.keepAwake.manualUntil != nil {
            Button("Turn Off Keep Awake") { app.keepAwake.stop() }
        } else {
            Menu("Keep Awake") {
                Button("Until Turned Off") { app.keepAwake.start(minutes: nil) }
                Button("15 Minutes") { app.keepAwake.start(minutes: 15) }
                Button("1 Hour") { app.keepAwake.start(minutes: 60) }
                Button("2 Hours") { app.keepAwake.start(minutes: 120) }
            }
        }
        if app.menuBar.isInstalled {
            Button(app.menuBar.isCollapsed ? "Show Hidden Menu Bar Icons" : "Hide Menu Bar Icons") {
                app.menuBar.toggle()
            }
        }
        Divider()
        Button("Settings…") { app.showSettings() }
            .keyboardShortcut(",")
        Button("Quit Tooki") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
