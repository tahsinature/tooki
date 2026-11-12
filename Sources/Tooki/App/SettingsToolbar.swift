import AppKit

/// The settings window's toolbar: one selectable icon per page, like most Mac apps' settings.
@MainActor
final class SettingsToolbar: NSObject, NSToolbarDelegate {
    let toolbar = NSToolbar(identifier: "TookiSettingsToolbar")
    private let onSelect: (SettingsPage) -> Void
    private var buttons: [SettingsPage: SettingsToolbarButton] = [:]
    private var selectedPage: SettingsPage = .general

    init(onSelect: @escaping (SettingsPage) -> Void) {
        self.onSelect = onSelect
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
    }

    func select(_ page: SettingsPage) {
        selectedPage = page
        for (buttonPage, button) in buttons {
            button.state = buttonPage == page ? .on : .off
        }
    }

    /// Puts a dot on the About icon, so a new version is noticed from any page.
    func showUpdateBadge(_ isVisible: Bool) {
        let about = toolbar.items.first { $0.itemIdentifier == Self.identifier(for: .about) }
        about?.image = Self.image(for: .about, badged: isVisible)
        buttons[.about]?.image = about?.image
        about?.toolTip = isVisible ? "A new version of \(BuildInfo.appName) is available" : SettingsPage.about.title
        buttons[.about]?.toolTip = about?.toolTip
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPage.allCases.map(Self.identifier(for:))
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [] // The complete custom button draws selection, rather than an icon-only native bezel.
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let page = SettingsPage(rawValue: identifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = page.toolbarLabel
        item.toolTip = page.title
        item.image = Self.image(for: page, badged: false)
        item.target = self
        item.action = #selector(itemClicked(_:))
        let button = SettingsToolbarButton(title: page.toolbarLabel, image: item.image, target: self, action: #selector(buttonClicked(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(page.rawValue)
        button.toolTip = page.title
        button.state = page == selectedPage ? .on : .off
        buttons[page] = button
        item.view = button
        return item
    }

    @objc private func buttonClicked(_ button: NSButton) {
        guard let name = button.identifier?.rawValue, let page = SettingsPage(rawValue: name) else { return }
        select(page)
        onSelect(page)
    }

    @objc private func itemClicked(_ item: NSToolbarItem) {
        guard let page = SettingsPage(rawValue: item.itemIdentifier.rawValue) else { return }
        select(page)
        onSelect(page)
    }

    private static func identifier(for page: SettingsPage) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(page.rawValue)
    }

    private static func image(for page: SettingsPage, badged: Bool) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: page.icon, accessibilityDescription: page.title)?
            .withSymbolConfiguration(.init(pointSize: 20, weight: .regular)) else { return nil }
        guard badged else { return symbol }
        // Drawn when shown, so the label color matches light or dark mode.
        let badge = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)
            let dot = CGRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 6, height: 6)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        badge.isTemplate = false
        return badge
    }
}
