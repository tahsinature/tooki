// Ported from asyar-calculator/src/currency.rs @ 034a38c
import Foundation
import Testing
@testable import TookiKit

struct CurrencyTests {
    private let sampleRates: [String: Double] = ["USD": 1, "EUR": 0.9, "IQD": 1310]
    private let fetchedAt = Date(timeIntervalSince1970: 1_000_000)

    /// A scratch folder under `.build/`, never `/tmp`.
    private func scratchDirectory(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/calculator-tests/\(name)-\(UUID().uuidString)")
    }

    /// Hits the live network; enable manually to check crypto rates still arrive.
    @Test(.disabled("hits the live network"))
    func fetchRatesIncludesCrypto() async throws {
        let rates = try await RatesFetcher.fetchRates()
        #expect(rates["USD"] != nil)
        #expect(rates["BTC"] != nil)
    }

    @Test func cacheAgeAndStaleness() {
        let cache = RatesCache(rates: sampleRates, fetchedAt: fetchedAt)
        #expect(cache.ageSeconds(at: fetchedAt) == 0)
        #expect(!cache.isStale(ttlHours: 6, at: fetchedAt.addingTimeInterval(5 * 3600)))
        #expect(cache.isStale(ttlHours: 6, at: fetchedAt.addingTimeInterval(7 * 3600)))
    }

    @Test func ageHumanFormats() {
        let cache = RatesCache(rates: sampleRates, fetchedAt: fetchedAt)
        #expect(cache.ageDescription(at: fetchedAt.addingTimeInterval(180)) == "3 min")
        #expect(cache.ageDescription(at: fetchedAt.addingTimeInterval(2 * 3600)) == "2 h")
        #expect(cache.ageDescription(at: fetchedAt.addingTimeInterval(26 * 3600)) == "1 d")
    }

    @Test func saveLoadRoundtrip() throws {
        let directory = scratchDirectory("roundtrip")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("nested/rates.json")
        let cache = RatesCache(rates: sampleRates, fetchedAt: fetchedAt)
        try cache.save(to: url)
        let loaded = try #require(RatesCache.load(from: url))
        #expect(loaded.fetchedAtEpochSeconds == cache.fetchedAtEpochSeconds)
        #expect(loaded.rates["IQD"] == 1310)
    }

    @Test func loadMissingOrCorruptReturnsNone() throws {
        let directory = scratchDirectory("corrupt")
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(RatesCache.load(from: directory.appendingPathComponent("nope.json")) == nil)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bad = directory.appendingPathComponent("bad.json")
        try Data("not json".utf8).write(to: bad)
        #expect(RatesCache.load(from: bad) == nil)
    }

    @Test func cryptoRatesMergeAsUnitsPerUsd() {
        var rates = sampleRates
        let body = Data(#"{"bitcoin":{"usd":80000.0},"ethereum":{"usd":2500.0},"junk":{"usd":0.0}}"#.utf8)
        RatesFetcher.mergeCryptoPrices(body, into: &rates)
        #expect(abs(rates["BTC"]! - 1.0 / 80000) < 1e-12)
        #expect(abs(rates["ETH"]! - 1.0 / 2500) < 1e-12)
        #expect(rates["IQD"] == 1310)
        #expect(rates["JUNK"] == nil)
    }

    /// Adapted: fend's rate handler is replaced by currency units built from the rates map.
    @Test func fendHandlerReturnsUnitsPerUsd() throws {
        let iqd = try #require(CurrencyUnits.resolve("IQD", rates: sampleRates))
        #expect(abs(iqd.display.factor - 1.0 / 1310) < 1e-15)
        #expect(CurrencyUnits.resolve("USD", rates: sampleRates)?.display.factor == 1)
        #expect(CurrencyUnits.resolve("XXX_UNKNOWN", rates: sampleRates) == nil)
    }
}
