import Foundation

/// Panel state stays in memory for the current Tooki session.
public struct PanelNavigationConfig: Codable, Equatable, Sendable {
    public var resumeLastPanel = true
    public var rememberToolPosition = true
    /// Empty disables the panel-local return shortcut.
    public var rootSearchShortcut = "cmd+escape"

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PanelNavigationConfig()
        resumeLastPanel = try container.decode(.resumeLastPanel, default: defaults.resumeLastPanel)
        rememberToolPosition = try container.decode(.rememberToolPosition, default: defaults.rememberToolPosition)
        rootSearchShortcut = try container.decode(.rootSearchShortcut, default: defaults.rootSearchShortcut)
    }
}
