import Foundation

/// The whole user configuration, stored as `config.json`.
/// Every field is optional in the file; missing fields fall back to defaults.
public struct TookiConfig: Codable, Equatable, Sendable {
    public var hyperKey = HyperKeyConfig()
    public var snippets = SnippetsConfig()
    public var clipboard = ClipboardConfig()
    public var menuBar = MenuBarConfig()
    public var keepAwake = KeepAwakeConfig()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TookiConfig()
        hyperKey = try container.decode(.hyperKey, default: defaults.hyperKey)
        snippets = try container.decode(.snippets, default: defaults.snippets)
        clipboard = try container.decode(.clipboard, default: defaults.clipboard)
        menuBar = try container.decode(.menuBar, default: defaults.menuBar)
        keepAwake = try container.decode(.keepAwake, default: defaults.keepAwake)
    }
}

public struct HotkeyBinding: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var action: String

    public init(key: String, action: String) {
        self.key = key
        self.action = action
    }
}

public struct HyperKeyConfig: Codable, Equatable, Sendable {
    public var enabled = true
    public var bindings: [HotkeyBinding] = [
        HotkeyBinding(key: "s", action: "search"),
        HotkeyBinding(key: "v", action: "clipboard"),
        HotkeyBinding(key: "a", action: "keepAwake.toggle"),
        HotkeyBinding(key: "m", action: "menuBar.search"),
        HotkeyBinding(key: ",", action: "settings"),
    ]

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = HyperKeyConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        bindings = try container.decode(.bindings, default: defaults.bindings)
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

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = MenuBarConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        startCollapsed = try container.decode(.startCollapsed, default: defaults.startCollapsed)
        autoHideSeconds = try container.decode(.autoHideSeconds, default: defaults.autoHideSeconds)
        layout = try container.decodeIfPresent(MenuBarLayout.self, forKey: .layout)
        restoreLayout = try container.decode(.restoreLayout, default: defaults.restoreLayout)
    }
}

public enum KeepAwakeMode: String, Codable, CaseIterable, Sendable {
    /// Screen and system stay on.
    case display
    /// System stays on, the screen may sleep (and lock).
    case system
}

public struct KeepAwakeConfig: Codable, Equatable, Sendable {
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
        mode = try container.decode(.mode, default: defaults.mode)
        defaultDurationMinutes = try container.decode(.defaultDurationMinutes, default: defaults.defaultDurationMinutes)
        onlyOnPower = try container.decode(.onlyOnPower, default: defaults.onlyOnPower)
        activateForApps = try container.decode(.activateForApps, default: defaults.activateForApps)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue
    }
}
