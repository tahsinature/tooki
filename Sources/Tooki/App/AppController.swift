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
    let shelves = ShelfLibrary()
    let keepAwake = KeepAwake()
    let menuBar = MenuBarOrganizer()
    let detective = ShortcutDetective()
    let updater = Updater()
    let buildClock = BuildClock()
    @ObservationIgnored lazy var menuBarArranger = MenuBarArranger(organizer: menuBar)
    private(set) var hasAccessibility = Accessibility.isTrusted

    @ObservationIgnored private let hyperKey = HyperKeyController()
    @ObservationIgnored private let shortcuts = ShortcutController()
    @ObservationIgnored private let snippetInserter = SnippetInserter()
    @ObservationIgnored private let snippetUsage = SnippetUsage()
    @ObservationIgnored private lazy var snippetPanel = SnippetPanelController(
        snippets: snippets, usage: snippetUsage, inserter: snippetInserter
    )
    @ObservationIgnored private lazy var searchPanel: SearchPanelController = {
        let panel = SearchPanelController()
        panel.onOpenSettings = { [weak self] in self?.showSettings() }
        return panel
    }()
    @ObservationIgnored private lazy var clipboardPanel = ClipboardPanelController(history: clipboard, shelves: shelfWindows)
    @ObservationIgnored private let emojiPanel = EmojiPanelController()
    @ObservationIgnored let appCatalog = AppCatalog()
    @ObservationIgnored let currencyRates = CurrencyRates(
        cacheURL: StoragePaths.dataDirectory.appending(path: "calculator/rates.json")
    )
    @ObservationIgnored private(set) lazy var shelfWindows = ShelfWindows(library: shelves)
    @ObservationIgnored private lazy var shelfManager = ShelfManagerController(windows: shelfWindows)
    @ObservationIgnored private let shelfDragWatcher = ShelfDragWatcher()
    @ObservationIgnored private lazy var snippetExpander = SnippetExpander(snippets: snippets, inserter: snippetInserter, usage: snippetUsage)
    @ObservationIgnored private lazy var keyboardMonitor = KeyboardMonitor(handlers: [hyperKey, detective, shortcuts, snippetExpander])
    @ObservationIgnored private lazy var mainWindow = MainWindowController(app: self)
    @ObservationIgnored private var lastPanel: (any ResumablePanelController)?
    @ObservationIgnored private var pollTimer: Timer?
    /// `tooki://` links that arrived while Tooki was still starting up.
    @ObservationIgnored private var pendingURLs: [URL]? = []

    var isCoffeeIconInserted: Bool {
        config.value.keepAwake.showMenuBarIcon && keepAwake.isActive
    }

    var loadErrors: [String] {
        [config.loadError, snippets.loadError].compactMap { $0 }
    }

    func start() {
        buildClock.start()
        config.load()
        snippets.load()
        clipboard.load()
        config.onChange = { [weak self] in self?.apply($0) }
        shortcuts.onAction = { [weak self] in self?.perform($0) }
        PanelShortcutRouter.onRootSearchShortcut(combo: { [weak self] in
            guard let self, !shortcuts.isPaused else { return nil }
            return KeyCombo(config.value.panelNavigation.rootSearchShortcut)
        }) { [weak self] in self?.showSearch(.everything) }
        apply(config.value)
        startShelf()
        Task { await appCatalog.refresh() }
        Task { await currencyRates.refreshIfStale() }

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
        buildClock.stop()
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
        case .snippets: toggleSnippets()
        case .emoji: toggleEmoji()
        case .shelfManager: toggleShelfManager()
        case .searchMenuBar: Task { await toggleMenuBarSearch() }
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
        case .shelf(let command): shelfWindows.handle(command)
        case .run(let action): perform(action)
        case nil: NSSound.beep()
        }
    }

    func toggleShelf() {
        shelfWindows.toggleAll()
    }

    /// Stops shortcuts from firing while one is being recorded.
    func setRecordingShortcut(_ isRecording: Bool) {
        shortcuts.isPaused = isRecording
    }

    func showSettings(_ page: SettingsPage? = nil) {
        mainWindow.show(page: page)
    }

    func toggleSearch(_ mode: SearchPanelController.Mode) {
        if mode == .everything, PanelShortcutRouter.hideShelf(NSApp.keyWindow) { return }
        if mode == .everything, config.value.panelNavigation.resumeLastPanel, let lastPanel {
            if lastPanel.panel?.isKeyWindow == true {
                lastPanel.close()
                return
            }
            closePanels(except: lastPanel)
            if lastPanel.resume() { return }
        }
        presentSearch(mode, toggling: true)
    }

    /// Opens search even when it's already showing, e.g. for ⌘Esc from another panel.
    func showSearch(_ mode: SearchPanelController.Mode) {
        presentSearch(mode, toggling: false)
    }

    private func presentSearch(_ mode: SearchPanelController.Mode, toggling: Bool) {
        closePanels(except: searchPanel)
        lastPanel = searchPanel
        searchPanel.onBack = nil
        let items = SearchItems(app: self)
        searchPanel.refreshItems = { [weak self] in
            guard let self else { return [] }
            return SearchItems(app: self).all()
        }
        if toggling {
            searchPanel.toggle(mode, items: items.all(), calculate: items.calculation)
        } else {
            searchPanel.show(mode, items: items.all(), calculate: items.calculation)
        }
        // Picks up apps installed since the last scan, ready for next time.
        Task { await appCatalog.refresh() }
        Task { await currencyRates.refreshIfStale() }
    }

    func toggleSnippets() {
        closePanels(except: snippetPanel)
        lastPanel = snippetPanel
        snippetPanel.onBack = backToSearch()
        snippetPanel.toggle()
    }

    func createSnippet() {
        closePanels(except: snippetPanel)
        lastPanel = snippetPanel
        snippetPanel.onBack = backToSearch()
        snippetPanel.show(creating: true)
    }

    func toggleClipboard() {
        closePanels(except: clipboardPanel)
        lastPanel = clipboardPanel
        clipboardPanel.onBack = backToSearch()
        clipboardPanel.toggle()
    }

    func toggleShelfManager() {
        closePanels(except: shelfManager)
        lastPanel = shelfManager
        shelfManager.onBack = backToSearch()
        shelfManager.toggle(library: shelves)
    }

    func toggleEmoji() {
        closePanels(except: emojiPanel)
        lastPanel = emojiPanel
        emojiPanel.onBack = backToSearch()
        emojiPanel.toggle()
    }

    /// Managers return to the saved parent query, even when opened by a dedicated shortcut.
    private func backToSearch() -> () -> Void {
        return { [weak self] in self?.returnToRootSearch() }
    }

    private func returnToRootSearch() {
        closePanels(except: searchPanel)
        lastPanel = searchPanel
        searchPanel.onBack = nil
        if !searchPanel.resume(.everything) {
            presentSearch(.everything, toggling: false)
        }
    }

    /// Only one floating panel shows at a time.
    private func closePanels(except kept: AnyObject) {
        if kept !== searchPanel { searchPanel.close() }
        if kept !== clipboardPanel { clipboardPanel.close() }
        if kept !== emojiPanel { emojiPanel.close() }
        if kept !== snippetPanel { snippetPanel.close() }
        if kept !== shelfManager { shelfManager.close() }
    }

    func toggleMenuBarSearch() async {
        lastPanel = searchPanel
        closePanels(except: searchPanel)
        if searchPanel.isShowing(.menuBar) {
            searchPanel.close()
            return
        }
        let items = await SearchItems(app: self).menuBarItems()
        searchPanel.refreshMenuBarItems = { [weak self] in
            guard let self else { return [] }
            return await SearchItems(app: self).menuBarItems()
        }
        searchPanel.onBack = backToSearch()
        searchPanel.show(.menuBar, items: items)
    }

    private func startShelf() {
        shelfWindows.start()
        shelfDragWatcher.onShiftDrag = { [weak self] in self?.shelfWindows.showForDrag() }
        shelfDragWatcher.onDragEnded = { [weak self] in self?.shelfWindows.dragEnded() }
    }

    private func applyShelf(_ config: ShelfConfig) {
        shelfWindows.apply(config)
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
        updater.setChecksAutomatically(config.updates.checkAutomatically)
    }

    private func startKeyboardMonitor() {
        guard hasAccessibility, keyboardMonitor.start() else { return }
        hyperKey.apply(config.value.hyperKey, isMonitoring: true)
    }

    private func poll() {
        SingleInstance.quitIfProductionIsRunning()
        reloadFromDisk()
        shelves.dropMissingFiles()
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
    /// Opens the app, or hides it when it's already in front, so one shortcut toggles it.
    @MainActor
    static func open(_ target: String) {
        guard let url = url(for: target) else {
            NSSound.beep()
            return
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleURL?.standardizedFileURL == url.standardizedFileURL {
            front.hide()
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
