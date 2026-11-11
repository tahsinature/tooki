import Foundation
import os

/// Exchange rates on disk: units of each currency per one US dollar, and when they were fetched.
public struct RatesCache: Codable, Sendable, Equatable {
    public static let defaultTTLHours = 6.0

    public var rates: [String: Double]
    public var fetchedAtEpochSeconds: UInt64

    private enum CodingKeys: String, CodingKey {
        case rates
        case fetchedAtEpochSeconds = "fetched_at_epoch_secs"
    }

    public init(rates: [String: Double], fetchedAt: Date) {
        self.rates = rates
        fetchedAtEpochSeconds = UInt64(max(0, fetchedAt.timeIntervalSince1970))
    }

    public func ageSeconds(at now: Date) -> UInt64 {
        let nowSeconds = UInt64(max(0, now.timeIntervalSince1970))
        return nowSeconds > fetchedAtEpochSeconds ? nowSeconds - fetchedAtEpochSeconds : 0
    }

    public func isStale(ttlHours: Double, at now: Date) -> Bool {
        Double(ageSeconds(at: now)) > ttlHours * 3600
    }

    /// `just now`, `3 min`, `2 h`, `1 d`.
    public func ageDescription(at now: Date) -> String {
        let seconds = ageSeconds(at: now)
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3600) h"
        default: return "\(seconds / 86_400) d"
        }
    }

    /// `nil` when the file is missing or unreadable.
    public static func load(from url: URL) -> RatesCache? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RatesCache.self, from: data)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// The app's exchange-rate store. It reads the disk cache lazily and only
/// touches the network when the caller asks for a refresh.
public final class CurrencyRates: Sendable {
    private struct State {
        var cache: RatesCache?
        var ttlHours = RatesCache.defaultTTLHours
        var hasLoadedDisk = false
        var isFetching = false
    }

    private let cacheURL: URL
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// `cacheURL` is where rates are persisted, e.g. `…/Application Support/Tooki/calculator/rates.json`.
    public init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    /// The rates and their age, for a `CalculatorContext`. Reads the disk cache on first use.
    public func snapshot(now: Date = Date()) -> (rates: [String: Double]?, age: String?) {
        loadDiskCacheOnce()
        guard let cache = state.withLock({ $0.cache }) else { return (nil, nil) }
        return (cache.rates, cache.ageDescription(at: now))
    }

    /// Missing rates count as stale.
    public func isStale(now: Date = Date()) -> Bool {
        loadDiskCacheOnce()
        return state.withLock { state in
            state.cache.map { $0.isStale(ttlHours: state.ttlHours, at: now) } ?? true
        }
    }

    /// Clamped to 1…24 hours like Asyar; zero or less restores the 6-hour default.
    public func setTTLHours(_ hours: Double) {
        let ttl = hours <= 0 ? RatesCache.defaultTTLHours : min(max(hours, 1), 24)
        state.withLock { $0.ttlHours = ttl }
    }

    /// Fetches when the rates are missing or stale. Calls made during a fetch return at once.
    public func refreshIfStale() async {
        guard isStale() else { return }
        await refresh()
    }

    /// Fetches fresh rates and saves them. Failures keep the previous rates.
    public func refresh() async {
        let shouldFetch = state.withLock { state in
            guard !state.isFetching else { return false }
            state.isFetching = true
            return true
        }
        guard shouldFetch else { return }
        defer { state.withLock { $0.isFetching = false } }

        guard let rates = try? await RatesFetcher.fetchRates() else { return }
        let cache = RatesCache(rates: rates, fetchedAt: Date())
        try? cache.save(to: cacheURL)
        state.withLock { $0.cache = cache }
    }

    private func loadDiskCacheOnce() {
        let needsLoad = state.withLock { state in
            defer { state.hasLoadedDisk = true }
            return !state.hasLoadedDisk
        }
        guard needsLoad, let cache = RatesCache.load(from: cacheURL) else { return }
        state.withLock { state in
            if state.cache == nil { state.cache = cache }
        }
    }
}
