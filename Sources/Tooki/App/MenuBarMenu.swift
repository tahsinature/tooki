import SwiftUI
import TookiKit

/// The menu under Tooki's menu bar icon, in three parts:
/// what's on right now (click to turn it off), controls, and the app itself.
struct MenuBarMenu: View {
    let app: AppController

    var body: some View {
        if hasActiveItems {
            Section("Active") { activeItems }
        }
        Section {
            controls
        } header: {
            BuildTimestamp(prefix: "Controls · \(BuildInfo.isRelease ? "Release" : "Dev")")
        }
        Section {
            Button("Show \(BuildInfo.appName)") { app.showSettings() }
                .keyboardShortcut(",")
            Button("Quit \(BuildInfo.appName)") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    // MARK: Active

    private var keepAwake: KeepAwake { app.keepAwake }
    private var shelves: ShelfLibrary { app.shelves }

    private var hasActiveItems: Bool {
        keepAwake.isActive || !shelves.isEmpty || app.detective.isListening
    }

    @ViewBuilder
    private var activeItems: some View {
        if keepAwake.manualUntil != nil {
            checkedItem("Keep Awake: \(keepAwake.statusText)") { keepAwake.stop() }
        } else if keepAwake.isActive {
            // Kept awake by a trigger app, so there's nothing to turn off here.
            Button("Keep Awake: \(keepAwake.statusText)") {}
                .disabled(true)
        }
        if !shelves.isEmpty {
            Button("\(ShelfText.shelfCount(shelves.shelves.count)) · \(ShelfText.itemCount(shelves.itemCount))") {
                app.shelfWindows.showAll()
            }
        }
        if app.detective.isListening {
            checkedItem("Shortcut Detective: Listening") { app.detective.stop() }
        }
    }

    /// A ticked item; choosing it turns the thing off.
    private func checkedItem(_ title: String, turnOff: @escaping () -> Void) -> some View {
        Toggle(title, isOn: Binding(get: { true }, set: { isOn in if !isOn { turnOff() } }))
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        Button("Search…") { app.toggleSearch(.everything) }
            .shortcutHint(for: .search, in: app)
        Button("Clipboard History…") { app.toggleClipboard() }
            .shortcutHint(for: .clipboard, in: app)
        Menu("Keep Awake") {
            if keepAwake.manualUntil != nil {
                Button("Turn Off") { keepAwake.stop() }
                Divider()
            }
            Button("Until Turned Off") { keepAwake.start(minutes: nil) }
            Button("15 Minutes") { keepAwake.start(minutes: 15) }
            Button("1 Hour") { keepAwake.start(minutes: 60) }
            Button("2 Hours") { keepAwake.start(minutes: 120) }
        }
        Menu("Shelves") { shelfControls }
        if app.menuBar.isInstalled {
            Button(app.menuBar.isCollapsed ? "Show Hidden Menu Bar Icons" : "Hide Menu Bar Icons") {
                app.menuBar.toggle()
            }
            .shortcutHint(for: .toggleMenuBar, in: app)
        }
    }

    @ViewBuilder
    private var shelfControls: some View {
        Button("New Shelf") { app.shelfWindows.newShelf() }
        Button("Show or Hide All") { app.toggleShelf() }
            .shortcutHint(for: .toggleShelf, in: app)
        if !shelves.isEmpty {
            Divider()
            ForEach(shelves.shelves) { shelf in
                Button("\(shelf.name) · \(ShelfText.itemCount(shelf.items.count))") {
                    app.shelfWindows.show(shelf, focus: true)
                }
            }
            Divider()
            Button("Clear All Shelves…") { app.shelfWindows.confirmCloseAll() }
        }
    }
}

private extension View {
    /// Shows the global shortcut bound to this action next to the menu item.
    @ViewBuilder
    func shortcutHint(for action: HotkeyAction, in app: AppController) -> some View {
        let binding = app.config.value.shortcuts.first { $0.enabled && HotkeyAction($0.action) == action }
        if let shortcut = binding.flatMap({ KeyCombo($0.keys) })?.keyboardShortcut {
            keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}

private extension KeyCombo {
    var keyboardShortcut: KeyboardShortcut? {
        let named: [String: KeyEquivalent] = [
            "space": .space, "return": .return, "tab": .tab, "escape": .escape,
            "left": .leftArrow, "right": .rightArrow, "up": .upArrow, "down": .downArrow,
        ]
        guard let equivalent = named[key] ?? (key.count == 1 ? KeyEquivalent(Character(key)) : nil) else { return nil }
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        return KeyboardShortcut(equivalent, modifiers: eventModifiers)
    }
}
