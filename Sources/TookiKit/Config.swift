import Foundation

/// The whole user configuration, stored as `config.json`.
/// Every field is optional in the file; missing fields fall back to defaults.
public struct TookiConfig: Codable, Equatable, Sendable {
    public var hyperKey = HyperKeyConfig()
    public var shortcuts = Shortcut.defaults
    public var snippets = SnippetsConfig()
    public var clipboard = ClipboardConfig()
    public var menuBar = MenuBarConfig()
    public var keepAwake = KeepAwakeConfig()
    public var shelf = ShelfConfig()
    public var updates = UpdatesConfig()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TookiConfig()
        hyperKey = try container.decode(.hyperKey, default: defaults.hyperKey)
        shortcuts = try container.decodeIfPresent([Shortcut].self, forKey: .shortcuts)
            ?? container.decodeIfPresent(LegacyHyperKeyConfig.self, forKey: .hyperKey)?.shortcuts
            ?? defaults.shortcuts
        snippets = try container.decode(.snippets, default: defaults.snippets)
        clipboard = try container.decode(.clipboard, default: defaults.clipboard)
        menuBar = try container.decode(.menuBar, default: defaults.menuBar)
        keepAwake = try container.decode(.keepAwake, default: defaults.keepAwake)
        shelf = try container.decode(.shelf, default: defaults.shelf)
        updates = try container.decode(.updates, default: defaults.updates)
    }
}

/// A global keyboard shortcut that runs a `HotkeyAction`.
public struct Shortcut: Codable, Equatable, Hashable, Sendable {
    public var action: String
    /// A `KeyCombo` like `hyper+s`. Empty when no hotkey is recorded yet.
    public var keys: String
    public var enabled: Bool

    public init(action: String, keys: String = "", enabled: Bool = true) {
        self.action = action
        self.keys = keys
        self.enabled = enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        keys = try container.decode(.keys, default: "")
        enabled = try container.decode(.enabled, default: true)
    }

    public static let defaults = [
        Shortcut(action: "search", keys: "hyper+s"),
        Shortcut(action: "clipboard", keys: "hyper+v"),
        Shortcut(action: "menuBar.search", keys: "hyper+m"),
    ]
}

public struct HyperKeyConfig: Codable, Equatable, Sendable {
    /// Off until the user turns it on, so a fresh install leaves Caps Lock alone.
    public var enabled = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(.enabled, default: HyperKeyConfig().enabled)
    }
}

/// Before `shortcuts` existed, bindings lived in `hyperKey` and always used Hyper.
private struct LegacyHyperKeyConfig: Decodable {
    struct Binding: Decodable {
        var key: String
        var action: String
    }

    var bindings: [Binding]?

    var shortcuts: [Shortcut]? {
        bindings?.map { Shortcut(action: $0.action, keys: "hyper+\($0.key)") }
    }
}

public struct SnippetsConfig: Codable, Equatable, Sendable {
    public var enabled = true
    public var keywordExpansion = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SnippetsConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        keywordExpansion = try container.decode(.keywordExpansion, default: defaults.keywordExpansion)
    }
}

public struct ClipboardConfig: Codable, Equatable, Sendable {
    public var enabled = true
    public var maxItems = 200
    /// Images take much more space than text, so they have their own limit. 0 turns images off.
    public var maxImages = 50
    public var persistHistory = true
    public var ignoredApps = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
    ]

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ClipboardConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        maxItems = try container.decode(.maxItems, default: defaults.maxItems)
        maxImages = try container.decode(.maxImages, default: defaults.maxImages)
        persistHistory = try container.decode(.persistHistory, default: defaults.persistHistory)
        ignoredApps = try container.decode(.ignoredApps, default: defaults.ignoredApps)
    }
}

public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var enabled = true
    public var startCollapsed = true
    /// Hide the revealed icons again after this many seconds. 0 keeps them visible.
    public var autoHideSeconds = 0
    /// The saved arrangement. `nil` leaves icon positions to macOS.
    public var layout: MenuBarLayout?
    /// Puts icons back into `layout` when apps launch, the Mac wakes or displays change.
    public var restoreLayout = true
    /// Adds a second divider. Icons left of it stay hidden until you ⌥-click the menu bar or choose Show All.
    public var alwaysHiddenSection = false
    /// Shows hidden icons in a bar below the menu bar (Thaw's "Thaw Bar") instead of in the menu bar.
    public var useThawBar = false
    public var thawBarLocation = ThawBarLocation.underMouse
    public var thawBarStyle = ThawBarStyle.material
    /// The Thaw Bar shows pictures of the icons instead of app icons. Needs Screen Recording.
    public var captureIconImages = false
    /// Reveal triggers on empty menu bar space.
    public var showOnHover = false
    public var showOnHoverDelay = 0.2
    public var showOnClick = false
    public var showOnScroll = false
    public var dividerStyle = MenuBarDividerStyle.line
    public var tint = MenuBarTint()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        startCollapsed = try container.decode(.startCollapsed, default: defaults.startCollapsed)
        autoHideSeconds = try container.decode(.autoHideSeconds, default: defaults.autoHideSeconds)
        layout = try container.decodeIfPresent(MenuBarLayout.self, forKey: .layout)
        restoreLayout = try container.decode(.restoreLayout, default: defaults.restoreLayout)
        alwaysHiddenSection = try container.decode(.alwaysHiddenSection, default: defaults.alwaysHiddenSection)
        useThawBar = try container.decode(.useThawBar, default: defaults.useThawBar)
        thawBarLocation = try container.decode(.thawBarLocation, default: defaults.thawBarLocation)
        thawBarStyle = try container.decode(.thawBarStyle, default: defaults.thawBarStyle)
        captureIconImages = try container.decode(.captureIconImages, default: defaults.captureIconImages)
        showOnHover = try container.decode(.showOnHover, default: defaults.showOnHover)
        showOnHoverDelay = try container.decode(.showOnHoverDelay, default: defaults.showOnHoverDelay)
        showOnClick = try container.decode(.showOnClick, default: defaults.showOnClick)
        showOnScroll = try container.decode(.showOnScroll, default: defaults.showOnScroll)
        dividerStyle = try container.decode(.dividerStyle, default: defaults.dividerStyle)
        tint = try container.decode(.tint, default: defaults.tint)
    }
}

public enum KeepAwakeMode: String, Codable, CaseIterable, Sendable {
    /// Screen and system stay on.
    case display
    /// System stays on, the screen may sleep (and lock).
    case system
}

public struct KeepAwakeConfig: Codable, Equatable, Sendable {
    public var showMenuBarIcon = false
    public var mode = KeepAwakeMode.display
    /// Duration used by the toggle shortcut. 0 means until turned off.
    public var defaultDurationMinutes = 0
    public var onlyOnPower = false
    /// Bundle identifiers that keep the Mac awake while they are running.
    public var activateForApps: [String] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KeepAwakeConfig()
        showMenuBarIcon = try container.decode(.showMenuBarIcon, default: defaults.showMenuBarIcon)
        mode = try container.decode(.mode, default: defaults.mode)
        defaultDurationMinutes = try container.decode(.defaultDurationMinutes, default: defaults.defaultDurationMinutes)
        onlyOnPower = try container.decode(.onlyOnPower, default: defaults.onlyOnPower)
        activateForApps = try container.decode(.activateForApps, default: defaults.activateForApps)
    }
}

public struct UpdatesConfig: Codable, Equatable, Sendable {
    /// Checks GitHub for a new release when Tooki starts and once a day.
    public var checkAutomatically = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checkAutomatically = try container.decode(.checkAutomatically, default: UpdatesConfig().checkAutomatically)
    }
}

public struct ShelfConfig: Codable, Equatable, Sendable {
    public var enabled = true
    /// Holding Shift while dragging something shows the shelf next to the pointer.
    public var shiftDragOpens = true
    /// Optional cleanup after any accepted drop. Off by default because file pickers also accept navigation drops.
    public var removeAfterDragOut = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ShelfConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        shiftDragOpens = try container.decode(.shiftDragOpens, default: defaults.shiftDragOpens)
        removeAfterDragOut = try container.decode(.removeAfterDragOut, default: defaults.removeAfterDragOut)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue
    }
}
