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
    let shelf = Shelf()
    let keepAwake = KeepAwake()
    let menuBar = MenuBarOrganizer()
    let detective = ShortcutDetective()
    @ObservationIgnored lazy var menuBarArranger = MenuBarArranger(organizer: menuBar)
    private(set) var hasAccessibility = Accessibility.isTrusted

    @ObservationIgnored private let hyperKey = HyperKeyController()
    @ObservationIgnored private let shortcuts = ShortcutController()
    @ObservationIgnored private let snippetInserter = SnippetInserter()
    @ObservationIgnored private let searchPanel = SearchPanelController()
    @ObservationIgnored private lazy var clipboardPanel = ClipboardPanelController(history: clipboard)
    @ObservationIgnored private lazy var shelfPanel = ShelfPanelController(shelf: shelf)
    @ObservationIgnored private let shelfDragWatcher = ShelfDragWatcher()
    @ObservationIgnored private lazy var snippetExpander = SnippetExpander(snippets: snippets, inserter: snippetInserter)
    @ObservationIgnored private lazy var keyboardMonitor = KeyboardMonitor(handlers: [hyperKey, detective, shortcuts, snippetExpander])
    @ObservationIgnored private lazy var mainWindow = MainWindowController(app: self)
    @ObservationIgnored private var pollTimer: Timer?
    /// `tooki://` links that arrived while Tooki was still starting up.
    @ObservationIgnored private var pendingURLs: [URL]? = []

    var loadErrors: [String] {
        [config.loadError, snippets.loadError].compactMap { $0 }
    }

    func start() {
        config.load()
        snippets.load()
        clipboard.load()
        config.onChange = { [weak self] in self?.apply($0) }
        shortcuts.onAction = { [weak self] in self?.perform($0) }
        apply(config.value)
        startShelf()

        startKeyboardMonitor()
        // Checks for external config edits and for the Accessibility grant.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if !hasAccessibility {
            Accessibility.requestAccess()
            showSettings(.general)
        }
        let urls = pendingURLs ?? []
        pendingURLs = nil
        urls.forEach(open)
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
        case .toggleShelf: toggleShelf()
        case .toggleKeepAwake: keepAwake.toggle()
        case .toggleMenuBar: menuBar.toggle()
        case .searchMenuBar: Task { await toggleMenuBarSearch() }
        case .settings: showSettings()
        case .open(let target): AppLauncher.open(target)
        }
    }

    /// Runs a `tooki://` link from another app or a script. Unknown links beep.
    func open(_ url: URL) {
        guard pendingURLs == nil else {
            pendingURLs?.append(url)
            return
        }
        switch TookiURLCommand(url) {
        case .shelf(let command): shelfPanel.handle(command)
        case .run(let action): perform(action)
        case nil: NSSound.beep()
        }
    }

    func toggleShelf() {
        shelfPanel.toggle()
    }

    func showShelf() {
        shelfPanel.handle(.show)
    }

    func clearShelf() {
        shelfPanel.handle(.clear)
    }

    /// Stops shortcuts from firing while one is being recorded.
    func setRecordingShortcut(_ isRecording: Bool) {
        shortcuts.isPaused = isRecording
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

    /// Brings back the saved shelf.
    private func startShelf() {
        shelf.load()
        if !shelf.isEmpty, shelfPanel.isEnabled { shelfPanel.show() }
        shelfDragWatcher.onShiftDrag = { [weak self] in self?.shelfPanel.showForDrag() }
        shelfDragWatcher.onDragEnded = { [weak self] in self?.shelfPanel.dragEnded() }
    }

    private func applyShelf(_ config: ShelfConfig) {
        shelfPanel.apply(config)
        if config.enabled, config.shiftDragOpens {
            shelfDragWatcher.start()
        } else {
            shelfDragWatcher.stop()
        }
    }

    private func apply(_ config: TookiConfig) {
        hyperKey.apply(config.hyperKey, isMonitoring: keyboardMonitor.isRunning)
        shortcuts.apply(config.shortcuts)
        snippetExpander.isEnabled = config.snippets.enabled && config.snippets.keywordExpansion
        clipboard.apply(config.clipboard)
        menuBar.apply(config.menuBar)
        menuBarArranger.apply(config.menuBar)
        keepAwake.apply(config.keepAwake)
        applyShelf(config.shelf)
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
        guard let url = url(for: target) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Resolves a bundle identifier (`com.apple.mail`) or path (`/Applications/Safari.app`).
    static func url(for target: String) -> URL? {
        target.hasPrefix("/")
            ? URL(fileURLWithPath: (target as NSString).expandingTildeInPath)
            : NSWorkspace.shared.urlForApplication(withBundleIdentifier: target)
    }
}
