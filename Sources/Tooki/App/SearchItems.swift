import AppKit
import TookiKit

/// Builds the entries shown in the search panel.
@MainActor
struct SearchItems {
    let app: AppController
    let inserter: SnippetInserter

    func all() -> [SearchItem] {
        snippetItems() + commandItems() + clipboardItems().prefix(20)
    }

    func snippetItems() -> [SearchItem] {
        app.snippets.value.map { snippet in
            SearchItem(
                id: "snippet-\(snippet.id)",
                title: snippet.name,
                keyword: snippet.keyword,
                kind: "Snippet",
                icon: "text.cursor",
                searchText: "\(snippet.collection) \(snippet.text)",
                copy: { Paster.copy(snippet.text) },
                run: { [inserter] in inserter.insert(snippet) }
            )
        }
    }

    func clipboardItems() -> [SearchItem] {
        app.clipboard.items.map { item in
            SearchItem(
                id: "clip-\(item.id)",
                title: item.title,
                kind: "Clipboard · \(item.copiedAt.formatted(.relative(presentation: .numeric)))",
                icon: item.image == nil ? "doc.on.clipboard" : "photo",
                searchText: item.image?.recognizedText ?? "",
                imageURL: item.image.map(ClipboardImageStore.url(for:)),
                copy: { [app] in app.clipboard.copy(item) },
                run: { [app] in app.clipboard.paste(item) }
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
            SearchItem(
                id: "menubar-\(index)",
                title: item.title,
                kind: isHidden(item) ? "Hidden" : "Shown",
                icon: "menubar.rectangle",
                searchText: "\(item.appName) \(item.label) \(item.bundleID ?? "")",
                appIcon: NSRunningApplication(processIdentifier: item.pid)?.icon,
                run: { Task { await MenuBarItemPresser.press(item, organizer: menuBar) } }
            )
        }
    }

    func commandItems() -> [SearchItem] {
        let app = self.app
        return [
            SearchItem(
                id: "cmd-keep-awake",
                title: app.keepAwake.manualUntil == nil ? "Turn On Keep Awake" : "Turn Off Keep Awake",
                kind: "Command",
                icon: "cup.and.saucer",
                run: { app.keepAwake.toggle() }
            ),
            SearchItem(
                id: "cmd-shelf",
                title: "Show or Hide Shelf",
                kind: "Command",
                icon: "tray.full",
                run: { app.toggleShelf() }
            ),
            SearchItem(
                id: "cmd-menu-bar",
                title: app.menuBar.isCollapsed ? "Show Hidden Menu Bar Icons" : "Hide Menu Bar Icons",
                kind: "Command",
                icon: "menubar.rectangle",
                run: { app.menuBar.toggle() }
            ),
            SearchItem(
                id: "cmd-menu-bar-search",
                title: "Search Menu Bar Items",
                kind: "Command",
                icon: "magnifyingglass",
                run: { Task { await app.toggleMenuBarSearch() } }
            ),
            SearchItem(
                id: "cmd-new-snippet",
                title: "Manage Snippets",
                kind: "Command",
                icon: "square.and.pencil",
                run: { app.showSettings(.snippets) }
            ),
            SearchItem(
                id: "cmd-settings",
                title: "Tooki Settings",
                kind: "Command",
                icon: "gearshape",
                run: { app.showSettings() }
            ),
        ]
    }
}
