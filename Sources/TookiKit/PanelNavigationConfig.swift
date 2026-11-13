import Foundation

/// Panel state stays in memory for the current Tooki session.
public struct PanelNavigationConfig: Codable, Equatable, Sendable {
    public var resumeLastPanel = true
    /// Empty disables the panel-local return shortcut.
    public var rootSearchShortcut = "cmd+escape"

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PanelNavigationConfig()
        resumeLastPanel = try container.decode(.resumeLastPanel, default: defaults.resumeLastPanel)
        rootSearchShortcut = try container.decode(.rootSearchShortcut, default: defaults.rootSearchShortcut)
    }
}
