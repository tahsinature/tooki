import AppKit
import SwiftUI

/// Search filters the sidebar independently of the currently displayed settings page.
struct MainView: View {
    let app: AppController
    @Bindable var navigation: SettingsNavigation
    let onPageChange: (SettingsPage) -> Void

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(navigation: navigation,
                            updater: app.updater,
                            needsAttention: !app.hasAccessibility || !app.loadErrors.isEmpty)
            VStack(spacing: 0) {
                SettingsNavigationBar(navigation: navigation)
                page
                    .id(navigation.page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(SettingsTheme.contentBackground)
        }
        .frame(minWidth: SettingsTheme.windowSize.width, minHeight: SettingsTheme.windowSize.height)
        .font(SettingsTheme.rowTitleFont)
        .foregroundStyle(SettingsTheme.primaryText)
        .background { SettingsGlassBackground() }
        .ignoresSafeArea()
        .onChange(of: navigation.page, initial: true) { onPageChange(navigation.page) }
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

    private static let defaultSize = SettingsTheme.windowSize
    private static let minimumSize = SettingsTheme.windowSize

    init(app: AppController) {
        self.app = app
    }

    func show(page: SettingsPage?) {
        if let page {
            navigation.query = ""
            navigation.page = page
        }
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
            contentRect: CGRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenNone)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        let rootView = MainView(
            app: app,
            navigation: navigation,
            onPageChange: { [weak window] page in
                window?.title = "\(page.title) · \(BuildInfo.appName)"
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        // Keep page fitting sizes from changing the window's resizing limits.
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        // Auto Layout supplies the true minimum; the sidebar and content can resize together.
        NSLayoutConstraint.activate([
            hostingController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumSize.width),
            hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumSize.height),
        ])
        window.center()
        window.setFrameAutosaveName("TookiCompactSettingsWindow")
        // Back to a menu bar only app once the window closes.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
        }
        return window
    }
}

