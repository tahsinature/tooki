import Foundation

/// The saved menu bar arrangement. Item IDs are listed left to right.
/// IDs of apps that aren't running are kept and skipped, so one config works on every Mac.
public struct MenuBarLayout: Codable, Equatable, Sendable {
    public var shown: [String] = []
    public var hidden: [String] = []

    public init(shown: [String] = [], hidden: [String] = []) {
        self.shown = shown
        self.hidden = hidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shown = try container.decode(.shown, default: [])
        hidden = try container.decode(.hidden, default: [])
    }
}

/// What identifies a menu bar item across launches and Macs.
public struct MenuBarItemDescriptor: Sendable {
    public var bundleID: String?
    /// The accessibility identifier, e.g. "com.apple.menuextra.wifi".
    public var identifier: String?
    public var appName: String

    public init(bundleID: String?, identifier: String?, appName: String) {
        self.bundleID = bundleID
        self.identifier = identifier
        self.appName = appName
    }
}

/// Works out which icon to move next to reach a saved layout, moving as few icons as possible.
public enum MenuBarLayoutPlanner {
    /// Tooki's separator: icons left of it are hidden.
    public static let separatorID = "tooki.separator"

    public enum Placement: Equatable, Sendable {
        case before(String)
        case after(String)
    }

    public struct Move: Equatable, Sendable {
        public var item: String
        public var placement: Placement
    }

    /// Stable IDs for items listed left to right.
    /// Apple's items use their accessibility identifier. Other apps use their bundle ID,
    /// with "#2", "#3"… for an app's second and later icons.
    public static func ids(for items: [MenuBarItemDescriptor]) -> [String] {
        var countPerApp: [String: Int] = [:]
        return items.map { item in
            if let identifier = item.identifier, !identifier.isEmpty, item.bundleID?.hasPrefix("com.apple.") == true {
                return identifier
            }
            let app = item.bundleID ?? item.appName
            let count = countPerApp[app, default: 0] + 1
            countPerApp[app] = count
            return count == 1 ? app : "\(app)#\(count)"
        }
    }

    /// The next icon to move, or `nil` when the bar already matches the layout.
    /// `current` lists the IDs in the menu bar left to right, including `separatorID`.
    /// Icons missing from the layout are left alone.
    public static func nextMove(current: [String], layout: MenuBarLayout) -> Move? {
        let present = Set(current)
        let target = unique(layout.hidden + [separatorID] + layout.shown).filter(present.contains)
        let targetIndex = Dictionary(uniqueKeysWithValues: target.enumerated().map { ($1, $0) })
        let ranks = current.compactMap { targetIndex[$0] }
        let inPlace = Set(longestIncreasingSubsequence(ranks).map { target[$0] })

        guard let index = target.firstIndex(where: { !inPlace.contains($0) }) else { return nil }
        let item = target[index]
        if let right = target[(index + 1)...].first(where: inPlace.contains) {
            return Move(item: item, placement: .before(right))
        }
        // Every item before this one is in place, so the previous one is a safe anchor.
        return index > 0 ? Move(item: item, placement: .after(target[index - 1])) : nil
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    /// The values (not positions) of one longest strictly increasing subsequence.
    static func longestIncreasingSubsequence(_ values: [Int]) -> [Int] {
        guard !values.isEmpty else { return [] }
        var length = [Int](repeating: 1, count: values.count)
        var previous = [Int](repeating: -1, count: values.count)
        for end in values.indices {
            for start in 0..<end where values[start] < values[end] && length[start] + 1 > length[end] {
                length[end] = length[start] + 1
                previous[end] = start
            }
        }
        var index = length.indices.max { length[$0] < length[$1] }!
        var result: [Int] = []
        while index >= 0 {
            result.append(values[index])
            index = previous[index]
        }
        return result.reversed()
    }
}
