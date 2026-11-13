import SwiftUI

/// Opts a panel into compact search and list styling without changing other panels.
private struct CompactPanelLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var compactPanelLayout: Bool {
        get { self[CompactPanelLayoutKey.self] }
        set { self[CompactPanelLayoutKey.self] = newValue }
    }
}
