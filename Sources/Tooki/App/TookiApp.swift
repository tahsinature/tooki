import SwiftUI

@main
struct TookiApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(app: delegate.app)
        } label: {
            Image(nsImage: MenuBarIcon.image)
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
        if app.keepAwake.manualUntil != nil {
            // Shows a checkmark; choosing it turns Keep Awake off.
            Toggle("Keep Awake: \(app.keepAwake.statusText)", isOn: Binding(
                get: { true },
                set: { isOn in if !isOn { app.keepAwake.stop() } }
            ))
        } else {
            Menu(app.keepAwake.isActive ? "Keep Awake: \(app.keepAwake.statusText)" : "Keep Awake") {
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
        Button("Show Tooki") { app.showSettings() }
            .keyboardShortcut(",")
        Button("Quit Tooki") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
