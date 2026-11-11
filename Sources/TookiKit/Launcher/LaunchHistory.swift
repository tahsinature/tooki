import Foundation

/// Remembers which launcher results you pick, so frequent and recent ones rank higher ("frecency").
public struct LaunchHistory: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var count: Int
        public var lastUsed: Date
    }

    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    public mutating func record(_ id: String, at date: Date = .now) {
        let count = (entries[id]?.count ?? 0) + 1
        entries[id] = Entry(count: count, lastUsed: date)
    }

    /// Up to 20 points added to a match score. Recent picks weigh more than old ones.
    public func boost(for id: String, now: Date = .now) -> Double {
        guard let entry = entries[id] else { return 0 }
        let days = now.timeIntervalSince(entry.lastUsed) / 86_400
        let recency: Double = switch days {
        case ..<1: 1
        case ..<7: 0.7
        case ..<30: 0.5
        default: 0.25
        }
        return min(20, Double(entry.count) * 4 * recency)
    }

    /// The most-used items, best first. Shown before you type anything.
    public func recentIDs(limit: Int, now: Date = .now) -> [String] {
        entries.keys
            .sorted { boost(for: $0, now: now) > boost(for: $1, now: now) }
            .prefix(limit)
            .map { $0 }
    }
}
