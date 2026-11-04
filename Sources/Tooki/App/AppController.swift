import AppKit
import Observation
import TookiKit

/// Owns every module and connects them to the configuration and the keyboard.
@MainActor
@Observable
final class AppController {
    let config = JSONDocument(
        fileURL: StoragePaths.configDirectory.appending(path: "config.json"),
        initialValue: TookiConfig()
    )
    let snippets = JSONDocument(
        fileURL: StoragePaths.configDirectory.appending(path: "snippets.json"),
        initialValue: Snippet.examples
    )
    let clipboard = ClipboardHistory()
    let keepAwake = KeepAwake()
    let menuBar = MenuBarOrganizer()
    private(set) var hasAccessibility = Accessibility.isTrusted

    @ObservationIgnored private let hyperKey = HyperKeyController()
    @ObservationIgnored private let snippetInserter = SnippetInserter()
    @ObservationIgnored private let searchPanel = SearchPanelController()
    @ObservationIgnored private lazy var clipboardPanel = ClipboardPanelController(history: clipboard)
    @ObservationIgnored private lazy var snippetExpander = SnippetExpander(snippets: snippets, inserter: snippetInserter)
    @ObservationIgnored private lazy var keyboardMonitor = KeyboardMonitor(handlers: [hyperKey, snippetExpander])
    @ObservationIgnored private lazy var mainWindow = MainWindowController(app: self)
    @ObservationIgnored private var pollTimer: Timer?

    var loadErrors: [String] {
        [config.loadError, snippets.loadError].compactMap { $0 }
    }

    func start() {
        config.load()
        snippets.load()
        clipboard.load()
        config.onChange = { [weak self] in self?.apply($0) }
        hyperKey.onAction = { [weak self] in self?.perform($0) }
        apply(config.value)

        startKeyboardMonitor()
        // Checks for external config edits and for the Accessibility grant.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if !hasAccessibility {
            Accessibility.requestAccess()
            showSettings(.general)
        }
    }

    func shutdown() {
        hyperKey.shutdown()
        keepAwake.shutdown()
    }

    func reloadFromDisk() {
        config.reloadIfChanged()
        snippets.reloadIfChanged()
    }

    func perform(_ action: HotkeyAction) {
        switch action {
        case .search: toggleSearch(.everything)
        case .clipboard: toggleClipboard()
        case .toggleKeepAwake: keepAwake.toggle()
        case .toggleMenuBar: menuBar.toggle()
        case .searchMenuBar: Task { await toggleMenuBarSearch() }
        case .settings: showSettings()
        case .open(let target): AppLauncher.open(target)
        }
    }

    func showSettings(_ page: SettingsPage? = nil) {
        mainWindow.show(page: page)
    }

    func toggleSearch(_ mode: SearchPanelController.Mode) {
        clipboardPanel.close()
        let items = SearchItems(app: self, inserter: snippetInserter)
        searchPanel.toggle(mode, items: items.all())
    }

    func toggleClipboard() {
        searchPanel.close()
        clipboardPanel.toggle()
    }

    func toggleMenuBarSearch() async {
        if searchPanel.isShowing(.menuBar) {
            searchPanel.close()
            return
        }
        let items = await SearchItems(app: self, inserter: snippetInserter).menuBarItems()
        searchPanel.show(.menuBar, items: items)
    }

    private func apply(_ config: TookiConfig) {
        hyperKey.apply(config.hyperKey, isMonitoring: keyboardMonitor.isRunning)
        snippetExpander.isEnabled = config.snippets.enabled && config.snippets.keywordExpansion
        clipboard.apply(config.clipboard)
        menuBar.apply(config.menuBar)
        keepAwake.apply(config.keepAwake)
    }

    private func startKeyboardMonitor() {
        guard hasAccessibility, keyboardMonitor.start() else { return }
        hyperKey.apply(config.value.hyperKey, isMonitoring: true)
    }

    private func poll() {
        reloadFromDisk()
        let trusted = Accessibility.isTrusted
        guard trusted != hasAccessibility else { return }
        hasAccessibility = trusted
        if trusted {
            startKeyboardMonitor()
        } else {
            keyboardMonitor.stop()
            hyperKey.apply(config.value.hyperKey, isMonitoring: false)
        }
    }
}

enum AppLauncher {
    @MainActor
    static func open(_ target: String) {
        let workspace = NSWorkspace.shared
        let url = target.hasPrefix("/")
            ? URL(fileURLWithPath: (target as NSString).expandingTildeInPath)
            : workspace.urlForApplication(withBundleIdentifier: target)
        guard let url else {
            NSSound.beep()
            return
        }
        workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
