import SwiftUI
import Observation

/// Shared keyboard movement and scroll requests for a panel and its Actions Menu.
@MainActor
@Observable
public final class PanelKeyboardNavigation {
    public init() {}

    public var resultsRevision = 0
    public var actionsRevision = 0
    public var resultsPageSize = 8
    public var actionsPageSize = 5

    public func moved(in area: PanelScrollArea) {
        switch area {
        case .results: resultsRevision += 1
        case .actions: actionsRevision += 1
        }
    }

    public func revision(in area: PanelScrollArea) -> Int {
        area == .results ? resultsRevision : actionsRevision
    }

    public func setPageSize(_ size: Int, in area: PanelScrollArea) {
        if area == .results { resultsPageSize = size } else { actionsPageSize = size }
    }

    public static func offset(for key: KeyEquivalent, modifiers: EventModifiers = [], pageSize: Int, stride: Int = 1) -> Int? {
        switch key {
        case .upArrow: modifiers.contains(.command) ? -Int.max / 2 : -stride
        case .downArrow: modifiers.contains(.command) ? Int.max / 2 : stride
        case .pageUp: -pageSize
        case .pageDown: pageSize
        case .home: -Int.max / 2
        case .end: Int.max / 2
        default: nil
        }
    }
}

private struct PanelKeyboardNavigationKey: EnvironmentKey {
    static let defaultValue: PanelKeyboardNavigation? = nil
}

extension EnvironmentValues {
    public var panelKeyboardNavigation: PanelKeyboardNavigation? {
        get { self[PanelKeyboardNavigationKey.self] }
        set { self[PanelKeyboardNavigationKey.self] = newValue }
    }
}
