import AppKit
import TookiKit

/// Builds the entries shown in the launcher.
@MainActor
struct SearchItems {
    let app: AppController

    /// Like Asyar's root search: apps and commands only. Snippets, clipboard and emoji
    /// are commands that open their own panels.
    func all() -> [SearchItem] {
        appItems() + commandItems()
    }

    /// The calculator card for a query that is a calculation, like `12 * 3` or `20% of 150`.
    func calculation(for query: String) -> SearchItem? {
        let rates = app.currencyRates.snapshot()
        let context = CalculatorContext(
            rates: rates.rates,
            ratesAge: rates.age,
            preferredCurrency: Locale.current.currency?.identifier ?? "USD"
        )
        guard let answer = Calculator.evaluate(query, context: context) else { return nil }
        let copyAnswer: @MainActor @Sendable () -> Void = { Paster.copy(answer.copyValue) }
        return SearchItem(
            id: "calculator",
            title: answer.value,
            kind: "Calculator",
            group: .calculator,
            icon: .symbol("equal.square"),
            calculation: SearchItem.Calculation(
                expression: query.trimmingCharacters(in: .whitespaces),
                result: answer.value,
                resultLabel: Self.label(for: answer.kind)
            ),
            actionTitle: "Copy Answer",
            copy: copyAnswer,
            run: copyAnswer
        )
    }

    private static func label(for kind: CalcKind) -> String {
        switch kind {
        case .math: "Number"
        case .unit: "Unit"
        case .currency: "Currency"
        case .date: "Date"
        case .time: "Time"
        case .base: "Base"
        case .color: "Color"
        case .percent: "Percent"
        case .ratio: "Ratio"
        }
    }

    func appItems() -> [SearchItem] {
        let catalog = app.appCatalog
        return catalog.apps.map { installed in
            SearchItem(
                id: "app-\(installed.url.path)",
                title: installed.name,
                kind: "Application",
                group: .applications,
                icon: .image(catalog.icon(for: installed)),
                actionTitle: "Open Application",
                extraActions: [
                    SearchAction(id: "reveal", title: "Show in Finder", icon: .symbol("folder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([installed.url])
                    },
                ],
                copy: { Paster.copy(installed.url.path) },
                run: { NSWorkspace.shared.openApplication(at: installed.url, configuration: NSWorkspace.OpenConfiguration()) }
            )
        }
    }

    /// Shown icons first, then hidden ones, each from right to left as in the menu bar.
    func menuBarItems() async -> [SearchItem] {
        let menuBar = app.menuBar
        let boundary = menuBar.hiddenBoundaryX
        func isHidden(_ item: MenuBarItem) -> Bool {
            boundary.map { item.frame.midX < $0 } ?? !item.isOnScreen
        }
        let sorted = await MenuBarItemScanner.scan().sorted { first, second in
            isHidden(first) == isHidden(second) ? first.frame.minX > second.frame.minX : !isHidden(first)
        }
        return sorted.enumerated().map { index, item in
            let appIcon = NSRunningApplication(processIdentifier: item.pid)?.icon
            return SearchItem(
                id: "menubar-\(item.bundleID ?? item.appName)-\(item.title)",
                title: item.title,
                kind: isHidden(item) ? "Hidden" : "Shown",
                group: .menuBar,
                icon: appIcon.map(PanelIcon.image) ?? .symbol("menubar.rectangle"),
                searchText: "\(item.appName) \(item.label) \(item.bundleID ?? "")",
                actionTitle: "Click Item",
                run: { Task { await MenuBarItemPresser.press(item, organizer: menuBar) } }
            )
        }
    }

    func commandItems() -> [SearchItem] {
        let app = self.app
        func command(_ id: String, _ title: String, icon: String, run: @escaping @MainActor () -> Void) -> SearchItem {
            SearchItem(
                id: "cmd-\(id)",
                title: title,
                kind: "Command",
                group: .commands,
                icon: .symbol(icon),
                actionTitle: "Run Command",
                run: run
            )
        }
        return [
            command("keep-awake", app.keepAwake.manualUntil == nil ? "Turn On Keep Awake" : "Turn Off Keep Awake",
                    icon: "cup.and.saucer") { app.keepAwake.toggle() },
            command("clipboard", "Clipboard History", icon: "doc.on.clipboard") { app.toggleClipboard(fromSearch: true) },
            command("snippets", "Search Snippets", icon: "text.cursor") { app.toggleSnippets(fromSearch: true) },
            command("emoji", "Emoji Picker", icon: "face.smiling") { app.toggleEmoji(fromSearch: true) },
            command("shelf", "Show or Hide Shelf", icon: "tray.full") { app.toggleShelf() },
            command("shelf-manager", "Shelf Manager", icon: "tray.2") { app.toggleShelfManager(fromSearch: true) },
            command("menu-bar", app.menuBar.isCollapsed ? "Show Hidden Menu Bar Icons" : "Hide Menu Bar Icons",
                    icon: "menubar.rectangle") { app.menuBar.toggle() },
            command("menu-bar-search", "Search Menu Bar Items", icon: "magnifyingglass") {
                Task { await app.toggleMenuBarSearch(fromSearch: true) }
            },
            command("new-snippet", "Create Snippet", icon: "square.and.pencil") { app.createSnippet(fromSearch: true) },
            command("settings", "Tooki Settings", icon: "gearshape") { app.showSettings() },
        ]
    }
}
