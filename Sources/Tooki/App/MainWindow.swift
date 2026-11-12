import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, hyperKey, snippets, clipboard, shelf, menuBar, keepAwake, shortcuts, about

    var id: Self { self }

    var title: String {
        switch self {
        case .hyperKey: "Hyper Key"
        case .snippets: "Snippets"
        case .clipboard: "Clipboard"
        case .shelf: "Shelf"
        case .menuBar: "Menu Bar"
        case .keepAwake: "Keep Awake"
        case .shortcuts: "Shortcuts"
        case .general: "General"
        case .about: "About \(BuildInfo.appName)"
        }
    }

    var icon: String {
        switch self {
        case .hyperKey: "bolt.fill"
        case .snippets: "text.cursor"
        case .clipboard: "list.clipboard.fill"
        case .shelf: "tray.full.fill"
        case .menuBar: "menubar.rectangle"
        case .keepAwake: "cup.and.saucer.fill"
        case .shortcuts: "command"
        case .general: "gearshape.fill"
        case .about: "info.circle.fill"
        }
    }

    /// The color of the page's toolbar icon tile.
    var tileColor: Color {
        switch self {
        case .general: .gray
        case .hyperKey: .orange
        case .snippets: .purple
        case .clipboard: .blue
        case .shelf: .teal
        case .menuBar: .indigo
        case .keepAwake: .brown
        case .shortcuts: .pink
        case .about: .gray
        }
    }

    /// The toolbar label. Shorter than the title so nine items fit.
    var toolbarLabel: String {
        self == .about ? "About" : title
    }
}

/// The page the settings window shows. Shared so hotkeys and the menu bar can pick one.
@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage = .general
}

/// The selected settings page. The window's toolbar picks the page.
struct MainView: View {
    let app: AppController
    @Bindable var navigation: SettingsNavigation
    let onPageChange: (SettingsPage) -> Void
    let onUpdateAvailabilityChange: (Bool) -> Void

    var body: some View {
        page
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: navigation.page, initial: true) { onPageChange(navigation.page) }
            .onChange(of: app.updater.shouldPrompt, initial: true) { onUpdateAvailabilityChange(app.updater.shouldPrompt) }
    }

    @ViewBuilder
    private var page: some View {
        switch navigation.page {
        case .hyperKey: HyperKeyView(config: app.config) { navigation.page = .shortcuts }
        case .snippets: SnippetsView(app: app, onOpenShortcuts: { navigation.page = .shortcuts })
        case .clipboard: ClipboardView(config: app.config, history: app.clipboard)
        case .shelf: ShelfSettingsView(app: app, onOpenShortcuts: { navigation.page = .shortcuts }, onOpenGeneral: { navigation.page = .general })
        case .menuBar: MenuBarView(config: app.config, organizer: app.menuBar, arranger: app.menuBarArranger)
        case .keepAwake: KeepAwakeView(config: app.config, keepAwake: app.keepAwake)
        case .shortcuts: ShortcutsView(config: app.config, detective: app.detective, onRecordingChange: app.setRecordingShortcut)
        case .general: GeneralView(app: app)
        case .about: AboutView(updater: app.updater, config: app.config)
        }
    }
}

/// The settings window, managed manually so hotkeys and the menu bar can open it.
@MainActor
final class MainWindowController {
    private let app: AppController
    private let navigation = SettingsNavigation()
    private var window: NSWindow?
    private lazy var toolbar = SettingsToolbar { [weak self] page in self?.navigation.page = page }

    private static let width: CGFloat = 720
    private static let heightRange: ClosedRange<CGFloat> = 480...900

    init(app: AppController) {
        self.app = app
    }

    func show(page: SettingsPage?) {
        if let page { navigation.page = page }
        let window = window ?? makeWindow()
        self.window = window
        // A regular app while the window is open, so it shows in ⌘-Tab and the Dock.
        NSApp.setActivationPolicy(.regular)
        // Plain activate() asks politely and is refused when opened from the menu bar menu,
        // leaving Tooki behind other apps and last in ⌘-Tab.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: Self.width, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenNone)
        window.toolbar = toolbar.toolbar
        window.toolbarStyle = .preference
        let rootView = MainView(
            app: app,
            navigation: navigation,
            onPageChange: { [weak self, weak window] page in
                window?.title = page.title
                self?.toolbar.select(page)
            },
            onUpdateAvailabilityChange: { [weak self] in self?.toolbar.showUpdateBadge($0) }
        )
        let hostingController = NSHostingController(rootView: rootView)
        // Keep page fitting sizes from changing the window's resizing limits.
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        // NSWindow.contentMinSize is ignored with Auto Layout. Constrain the hosted view instead.
        // A fixed width, like System Settings: only the height can change.
        NSLayoutConstraint.activate([
            hostingController.view.widthAnchor.constraint(equalToConstant: Self.width),
            hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.heightRange.lowerBound),
            hostingController.view.heightAnchor.constraint(lessThanOrEqualToConstant: Self.heightRange.upperBound),
        ])
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.center()
        window.setFrameAutosaveName("TookiMainWindow")
        let height = min(max(window.contentLayoutRect.height, Self.heightRange.lowerBound), Self.heightRange.upperBound)
        window.setContentSize(CGSize(width: Self.width, height: height))
        // Back to a menu bar only app once the window closes.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
        }
        return window
    }
}

