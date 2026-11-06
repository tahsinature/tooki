import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case hyperKey, snippets, clipboard, shelf, menuBar, keepAwake, shortcuts, general, about

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

    var color: Color {
        switch self {
        case .hyperKey: .purple
        case .snippets: .blue
        case .clipboard: .orange
        case .shelf: .indigo
        case .menuBar: .teal
        case .keepAwake: .brown
        case .shortcuts: .pink
        case .general: .gray
        case .about: .gray
        }
    }

    var summary: String {
        switch self {
        case .hyperKey: "Turn Caps Lock into one extra modifier that no app uses, for shortcuts that never conflict."
        case .snippets: "Expand short keywords into text you type often, in any app."
        case .clipboard: "Keep a searchable history of everything you copy."
        case .shelf: "A floating spot to collect files and drag them out anywhere."
        case .menuBar: "Hide the menu bar icons you rarely need and keep the rest in order."
        case .keepAwake: "Stop your Mac from sleeping while you need it."
        case .shortcuts: "Run Tooki features and open apps with a keystroke."
        case .general: "Permissions, startup and where your configuration lives."
        case .about: "A toolkit for your Mac's keyboard, clipboard and menu bar."
        }
    }

    static let modules: [SettingsPage] = [.hyperKey, .snippets, .clipboard, .shelf, .menuBar, .keepAwake]
    static let appPages: [SettingsPage] = [.shortcuts, .general]
}

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage? = .snippets {
        didSet {
            guard let oldValue, oldValue != page, !isMovingThroughHistory else { return }
            backStack.append(oldValue)
            forwardStack.removeAll()
        }
    }

    private var backStack: [SettingsPage] = []
    private var forwardStack: [SettingsPage] = []
    private var isMovingThroughHistory = false

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func goBack() {
        guard let previous = backStack.popLast(), let current = page else { return }
        forwardStack.append(current)
        moveThroughHistory(to: previous)
    }

    func goForward() {
        guard let next = forwardStack.popLast(), let current = page else { return }
        backStack.append(current)
        moveThroughHistory(to: next)
    }

    private func moveThroughHistory(to destination: SettingsPage) {
        isMovingThroughHistory = true
        page = destination
        isMovingThroughHistory = false
    }
}

/// The settings shell keeps navigation stable while each tool supplies its own content.
struct MainView: View {
    static let sidebarWidth: CGFloat = 220

    let app: AppController
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SettingsSidebar(app: app, selection: $navigation.page)
                .navigationSplitViewColumnWidth(Self.sidebarWidth)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .scrollContentBackground(.hidden)
                .background(SettingsTheme.background)
                .navigationTitle(navigation.page?.title ?? BuildInfo.appName)
                .toolbar { historyButtons }
        }
        .tint(SettingsTheme.accent)
        .preferredColorScheme(.dark)
    }

    private var historyButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Back", systemImage: "chevron.left", action: navigation.goBack)
                .disabled(!navigation.canGoBack)
            Button("Forward", systemImage: "chevron.right", action: navigation.goForward)
                .disabled(!navigation.canGoForward)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.page ?? .snippets {
        case .hyperKey: HyperKeyView(config: app.config) { navigation.page = .shortcuts }
        case .snippets: SnippetsView(snippets: app.snippets)
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
    private var sidebarLock: SidebarWidthLock?

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
        // SwiftUI's column width limits are ignored on macOS 26, so lock the sidebar once it exists.
        DispatchQueue.main.async { [self] in
            if sidebarLock == nil { sidebarLock = SidebarWidthLock(window: window, width: MainView.sidebarWidth) }
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = BuildInfo.appName
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(SettingsTheme.background)
        // Each page shows its own title in its header card, like System Settings.
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        let hostingController = NSHostingController(rootView: MainView(app: app, navigation: navigation))
        // Keep page fitting sizes from changing the window's resizing limits.
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        let minimumSize = CGSize(width: 820, height: 520)
        // NSWindow.contentMinSize is ignored with Auto Layout. Constrain the hosted view instead.
        NSLayoutConstraint.activate([
            hostingController.view.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumSize.width),
            hostingController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumSize.height),
        ])
        window.center()
        window.setFrameAutosaveName("TookiMainWindow")
        let contentSize = window.contentLayoutRect.size
        if contentSize.width < minimumSize.width || contentSize.height < minimumSize.height {
            window.setContentSize(CGSize(
                width: max(contentSize.width, minimumSize.width),
                height: max(contentSize.height, minimumSize.height)
            ))
        }
        // Back to a menu bar only app once the window closes.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
        }
        return window
    }
}

