import Foundation

/// Downloads USD-based exchange rates from the same sources Asyar uses.
enum RatesFetcher {
    private static let fiatURL = URL(string: "https://api.exchangerate-api.com/v4/latest/USD")!
    private static let userAgent = "Tooki (+https://github.com/tahsinature/tooki)"

    /// CoinGecko ids and the codes they map to.
    static let cryptoIDs: [(id: String, code: String)] = [
        ("bitcoin", "BTC"), ("ethereum", "ETH"), ("binancecoin", "BNB"), ("solana", "SOL"),
        ("ripple", "XRP"), ("cardano", "ADA"), ("dogecoin", "DOGE"), ("litecoin", "LTC"),
        ("polkadot", "DOT"), ("tron", "TRX"), ("chainlink", "LINK"), ("bitcoin-cash", "BCH"),
        ("stellar", "XLM"), ("tether", "USDT"), ("usd-coin", "USDC"),
    ]

    private static var cryptoURL: URL {
        let ids = cryptoIDs.map(\.id).joined(separator: ",")
        return URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd")!
    }

    struct FetchError: Error {}

    /// Fiat rates are required; crypto prices are best-effort.
    static func fetchRates() async throws -> [String: Double] {
        let (fiatData, fiatResponse) = try await URLSession.shared.data(for: request(fiatURL))
        guard (fiatResponse as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else { throw FetchError() }
        var rates = try parseFiatRates(fiatData)
        if let (cryptoData, _) = try? await URLSession.shared.data(for: request(cryptoURL)) {
            mergeCryptoPrices(cryptoData, into: &rates)
        }
        return rates
    }

    /// `{"rates": {"eur": 0.9, …}}` → `["EUR": 0.9, …]`.
    static func parseFiatRates(_ data: Data) throws -> [String: Double] {
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = body["rates"] as? [String: Any] else { throw FetchError() }
        var rates: [String: Double] = [:]
        for (code, value) in entries {
            if let rate = (value as? NSNumber)?.doubleValue {
                rates[code.uppercased()] = rate
            }
        }
        guard !rates.isEmpty else { throw FetchError() }
        return rates
    }

    /// Stores each coin as units per one USD, like the fiat rates. Zero prices are skipped.
    static func mergeCryptoPrices(_ data: Data, into rates: inout [String: Double]) {
        guard let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        for (id, code) in cryptoIDs {
            guard let coin = body[id] as? [String: Any],
                  let price = (coin["usd"] as? NSNumber)?.doubleValue, price > 0 else { continue }
            rates[code] = 1 / price
        }
    }

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        // CoinGecko answers 403 to requests without a descriptive User-Agent.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}
