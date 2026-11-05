import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case hyperKey, snippets, clipboard, menuBar, keepAwake, shortcuts, general

    var id: Self { self }

    var title: String {
        switch self {
        case .hyperKey: "Hyper Key"
        case .snippets: "Snippets"
        case .clipboard: "Clipboard"
        case .menuBar: "Menu Bar"
        case .keepAwake: "Keep Awake"
        case .shortcuts: "Shortcuts"
        case .general: "General"
        }
    }

    var icon: String {
        switch self {
        case .hyperKey: "bolt.fill"
        case .snippets: "text.cursor"
        case .clipboard: "list.clipboard.fill"
        case .menuBar: "menubar.rectangle"
        case .keepAwake: "cup.and.saucer.fill"
        case .shortcuts: "command"
        case .general: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .hyperKey: .purple
        case .snippets: .blue
        case .clipboard: .orange
        case .menuBar: .teal
        case .keepAwake: .brown
        case .shortcuts: .pink
        case .general: .gray
        }
    }

    var summary: String {
        switch self {
        case .hyperKey: "Turn Caps Lock into one extra modifier that no app uses, for shortcuts that never conflict."
        case .snippets: "Expand short keywords into text you type often, in any app."
        case .clipboard: "Keep a searchable history of everything you copy."
        case .menuBar: "Hide the menu bar icons you rarely need and keep the rest in order."
        case .keepAwake: "Stop your Mac from sleeping while you need it."
        case .shortcuts: "Run Tooki features and open apps with a keystroke."
        case .general: "Permissions, startup and where your configuration lives."
        }
    }

    static let modules: [SettingsPage] = [.hyperKey, .snippets, .clipboard, .menuBar, .keepAwake]
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

/// Laid out like System Settings: a fixed sidebar of colored icons and grouped pages.
struct MainView: View {
    let app: AppController
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $navigation.page) {
                Section {
                    ForEach(SettingsPage.modules, content: SidebarRow.init)
                }
                Section {
                    ForEach(SettingsPage.appPages, content: SidebarRow.init)
                }
            }
            .safeAreaInset(edge: .top) { SidebarBrand() }
            // A fixed width so the sidebar can't be dragged closed.
            .frame(width: 220)
            .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .navigationTitle(navigation.page?.title ?? "Tooki")
                .toolbar { historyButtons }
        }
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
        case .menuBar: MenuBarView(config: app.config, organizer: app.menuBar, arranger: app.menuBarArranger)
        case .keepAwake: KeepAwakeView(config: app.config, keepAwake: app.keepAwake)
        case .shortcuts: ShortcutsView(config: app.config, detective: app.detective, onRecordingChange: app.setRecordingShortcut)
        case .general: GeneralView(app: app)
        }
    }
}

private struct SidebarRow: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 7) {
            IconTile(symbol: page.icon, color: page.color)
            Text(page.title)
        }
        .tag(page)
    }
}

/// The app icon and name, where System Settings has its search field.
private struct SidebarBrand: View {
    private var version: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tooki").font(.headline)
                if let version {
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// The settings window, managed manually so hotkeys and the menu bar can open it.
@MainActor
final class MainWindowController {
    private let app: AppController
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(app: AppController) {
        self.app = app
    }

    func show(page: SettingsPage?) {
        if let page { navigation.page = page }
        let window = window ?? makeWindow()
        self.window = window
        // A regular app while the window is open, so it shows in ⌘-Tab and the Dock.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1000, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Tooki"
        // Each page shows its own title in its header card, like System Settings.
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 820, height: 520)
        window.contentViewController = NSHostingController(rootView: MainView(app: app, navigation: navigation))
        window.center()
        window.setFrameAutosaveName("TookiMainWindow")
        // Back to a menu bar only app once the window closes.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
        }
        return window
    }
}
