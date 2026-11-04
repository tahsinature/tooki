import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case hyperKey, snippets, clipboard, menuBar, keepAwake, general

    var id: Self { self }

    var title: String {
        switch self {
        case .hyperKey: "Hyper Key"
        case .snippets: "Snippets"
        case .clipboard: "Clipboard"
        case .menuBar: "Menu Bar"
        case .keepAwake: "Keep Awake"
        case .general: "General"
        }
    }

    var icon: String {
        switch self {
        case .hyperKey: "bolt"
        case .snippets: "text.cursor"
        case .clipboard: "list.clipboard"
        case .menuBar: "menubar.rectangle"
        case .keepAwake: "cup.and.saucer"
        case .general: "gearshape"
        }
    }

    static let modules: [SettingsPage] = [.hyperKey, .snippets, .clipboard, .menuBar, .keepAwake]
}

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage? = .snippets
}

struct MainView: View {
    let app: AppController
    @Bindable var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.page) {
                Section("Modules") {
                    ForEach(SettingsPage.modules) { page in
                        Label(page.title, systemImage: page.icon).tag(page)
                    }
                }
                Section("App") {
                    Label(SettingsPage.general.title, systemImage: SettingsPage.general.icon)
                        .tag(SettingsPage.general)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { configBadge }
        } detail: {
            detail
                .navigationTitle(navigation.page?.title ?? "Tooki")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.page ?? .snippets {
        case .hyperKey: HyperKeyView(config: app.config)
        case .snippets: SnippetsView(snippets: app.snippets)
        case .clipboard: ClipboardView(config: app.config, history: app.clipboard)
        case .menuBar: MenuBarView(config: app.config, organizer: app.menuBar, arranger: app.menuBarArranger)
        case .keepAwake: KeepAwakeView(config: app.config, keepAwake: app.keepAwake)
        case .general: GeneralView(app: app)
        }
    }

    private var configBadge: some View {
        Button {
            navigation.page = .general
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    app.loadErrors.isEmpty ? "Config synced" : "Config has errors",
                    systemImage: app.loadErrors.isEmpty ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.caption.bold())
                Text("~/.config/tooki/")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(10)
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
