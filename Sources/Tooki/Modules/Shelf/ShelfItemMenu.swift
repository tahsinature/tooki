import AppKit

/// The right-click menu for shelf items. It acts on the selection when the clicked item is
/// part of it, like Finder; otherwise on the clicked item alone.
@MainActor
enum ShelfItemMenu {
    static func make(for items: [ShelfItem], on shelf: Shelf) -> NSMenu {
        let ready = items.filter { $0.exists && !shelf.copyingIDs.contains($0.id) }
        let urls = ready.map(\.url)
        let originals = ready.compactMap(\.originalPath).map { URL(fileURLWithPath: $0) }
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(action("Quick Look", enabled: !urls.isEmpty) { shelf.onQuickLook(urls) })
        menu.addItem(action("Open", enabled: !urls.isEmpty) { urls.forEach { NSWorkspace.shared.open($0) } })
        menu.addItem(openWithItem(for: urls))
        menu.addItem(.separator())

        menu.addItem(action("Show in Finder", enabled: !urls.isEmpty) {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        })
        if !originals.isEmpty {
            menu.addItem(action("Show Original in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(originals)
            })
        }
        menu.addItem(.separator())

        menu.addItem(action("Copy", enabled: !urls.isEmpty) { copy(urls as [NSURL]) })
        menu.addItem(action(urls.count > 1 ? "Copy Paths" : "Copy Path", enabled: !urls.isEmpty) {
            copy(urls.map(\.path).joined(separator: "\n") as NSString)
        })
        if !originals.isEmpty {
            menu.addItem(action(originals.count > 1 ? "Copy Original Paths" : "Copy Original Path") {
                copy(originals.map(\.path).joined(separator: "\n") as NSString)
            })
        }
        menu.addItem(.separator())

        menu.addItem(action("Rename…", enabled: ready.count == 1 && items.count == 1) {
            if let item = ready.first { ShelfRenamePrompt.run(for: item, on: shelf) }
        })
        menu.addItem(action("Remove from Shelf") { shelf.remove(Set(items.map(\.id))) })
        return menu
    }

    /// Apps that can open the first item, the default one first, like Finder's Open With.
    private static func openWithItem(for urls: [URL]) -> NSMenuItem {
        let item = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
        guard let first = urls.first else {
            item.isEnabled = false
            return item
        }
        let workspace = NSWorkspace.shared
        let defaultApp = workspace.urlForApplication(toOpen: first)
        let otherApps = workspace.urlsForApplications(toOpen: first)
            .filter { $0 != defaultApp }
            .sorted { appName($0).localizedStandardCompare(appName($1)) == .orderedAscending }
        let submenu = NSMenu()
        for app in [defaultApp].compactMap({ $0 }) + otherApps {
            let title = app == defaultApp ? "\(appName(app)) (default)" : appName(app)
            let appItem = action(title) {
                workspace.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            }
            let icon = workspace.icon(forFile: app.path)
            icon.size = CGSize(width: 16, height: 16)
            appItem.image = icon
            submenu.addItem(appItem)
            if app == defaultApp, !otherApps.isEmpty { submenu.addItem(.separator()) }
        }
        item.submenu = submenu
        item.isEnabled = !submenu.items.isEmpty
        return item
    }

    private static func appName(_ app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacing(/\.app$/, with: "")
    }

    private static func copy(_ object: NSPasteboardWriting) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([object])
    }

    private static func copy(_ objects: [NSURL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(objects)
    }

    private static func action(_ title: String, enabled: Bool = true, run: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, run: run)
        item.isEnabled = enabled
        return item
    }
}

/// A menu item that runs a closure, so menus can be built without a target object.
private final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(runAction), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func runAction() { run() }
}

/// Asks for a new name and renames the file on disk, then updates the shelf.
@MainActor
enum ShelfRenamePrompt {
    static func run(for item: ShelfItem, on shelf: Shelf) {
        let alert = NSAlert()
        alert.messageText = "Rename “\(item.url.lastPathComponent)”"
        alert.informativeText = item.isCopy
            ? "Renames Tooki's copy. The original keeps its name."
            : "Renames the real file in \(item.location ?? "its folder")."
        let field = NSTextField(string: item.url.lastPathComponent)
        field.frame = CGRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate()
        // Select the name without its extension, like Finder.
        DispatchQueue.main.async {
            let name = field.stringValue as NSString
            let length = name.pathExtension.isEmpty ? name.length : name.deletingPathExtension.count
            field.currentEditor()?.selectedRange = NSRange(location: 0, length: length)
        }
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try shelf.rename(item, to: field.stringValue)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
