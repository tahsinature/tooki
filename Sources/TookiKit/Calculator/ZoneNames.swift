import Foundation

/// A resolved world-clock zone. Keeps the IANA name for display because
/// Foundation reports `UTC` as `GMT`.
struct WorldZone: Sendable {
    let identifier: String
    let timeZone: TimeZone

    init?(identifier: String) {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        self.identifier = identifier
        self.timeZone = timeZone
    }

    init(_ timeZone: TimeZone) {
        identifier = timeZone.identifier
        self.timeZone = timeZone
    }

    /// `Europe/London` → `London`.
    var shortName: String {
        String(identifier.split(separator: "/").last ?? Substring(identifier)).replacingOccurrences(of: "_", with: " ")
    }

    func secondsFromGMT(at instant: Date) -> Int {
        timeZone.secondsFromGMT(for: instant)
    }
}

/// Resolves human city, country, airport and abbreviation names to time zones.
enum ZoneNames {
    /// Curated aliases: abbreviations, airports, countries and cities whose IANA zone carries a different name.
    private static let aliases: [String: String] = {
        let groups: [String: [String]] = [
            "America/Los_Angeles": ["sf", "san francisco", "sfo", "silicon valley", "la", "lax", "san diego", "seattle", "pst", "pdt", "pt"],
            "America/New_York": ["nyc", "ny", "new york city", "jfk", "boston", "miami", "washington", "washington dc", "dc", "est", "edt", "et", "usa", "united states", "america"],
            "America/Chicago": ["cst", "cdt", "ct", "houston", "dallas", "austin"],
            "America/Denver": ["mst", "mdt", "mt"],
            "Europe/London": ["ldn", "lon", "lhr", "bst", "uk"],
            "Europe/Berlin": ["cet", "cest", "munich", "fra", "frankfurt", "hamburg", "cologne", "germany"],
            "Europe/Paris": ["cdg", "france"],
            "Europe/Amsterdam": ["ams", "netherlands"],
            "Asia/Kolkata": ["ist", "delhi", "new delhi", "mumbai", "bangalore", "bengaluru", "chennai", "india"],
            "Asia/Tokyo": ["jst", "nrt", "hnd", "osaka", "kyoto", "japan"],
            "Asia/Seoul": ["kst", "icn", "busan", "korea", "south korea"],
            "Asia/Shanghai": ["beijing", "shenzhen", "guangzhou", "pek", "china"],
            "Asia/Dubai": ["dxb", "abu dhabi"],
            "Asia/Baghdad": ["erbil", "hewler", "sulaymaniyah", "duhok", "mosul", "basra", "iraq"],
            "Asia/Singapore": ["sin"],
            "Asia/Hong_Kong": ["hkg"],
            "Australia/Sydney": ["aest", "aedt", "canberra", "australia"],
            "Pacific/Honolulu": ["hst", "hawaii"],
            "America/Anchorage": ["akst", "akdt"],
            "Europe/Moscow": ["msk", "russia"],
            "Europe/Athens": ["eet", "greece"],
            "Europe/Lisbon": ["wet", "portugal"],
            "UTC": ["gmt", "utc", "zulu"],
            "America/Santiago": ["chile"],
            "Europe/Madrid": ["spain"],
            "Europe/Rome": ["italy"],
            "America/Sao_Paulo": ["brazil"],
            "America/Argentina/Buenos_Aires": ["argentina"],
            "America/Toronto": ["canada"],
            "America/Mexico_City": ["mexico"],
            "Europe/Istanbul": ["turkey"],
            "Africa/Cairo": ["egypt"],
            "Europe/Stockholm": ["sweden"],
            "Europe/Oslo": ["norway"],
            "Europe/Warsaw": ["poland"],
            "Asia/Bangkok": ["thailand"],
            "Asia/Ho_Chi_Minh": ["vietnam"],
            "Asia/Manila": ["philippines"],
            "Asia/Jakarta": ["indonesia"],
            "Asia/Karachi": ["pakistan"],
            "Asia/Riyadh": ["saudi arabia"],
            "Asia/Jerusalem": ["israel"],
            "Africa/Nairobi": ["kenya"],
            "Africa/Lagos": ["nigeria"],
            "Africa/Johannesburg": ["south africa"],
            "Pacific/Auckland": ["new zealand"],
            "Europe/Zurich": ["switzerland"],
            "Europe/Vienna": ["austria"],
            "Europe/Brussels": ["belgium"],
            "Europe/Copenhagen": ["denmark"],
            "Europe/Helsinki": ["finland"],
            "Europe/Dublin": ["ireland"],
        ]
        var map: [String: String] = [:]
        for (identifier, names) in groups {
            for name in names {
                map[name] = identifier
            }
        }
        return map
    }()

    /// Lowercased full IANA name and last segment (`new york`) → identifier, built once.
    private static let ianaNames: [String: String] = {
        var map: [String: String] = [:]
        for identifier in TimeZone.knownTimeZoneIdentifiers.sorted() {
            let full = identifier.lowercased()
            if let lastSegment = full.split(separator: "/").last {
                let name = lastSegment.replacingOccurrences(of: "_", with: " ")
                if map[name] == nil {
                    map[name] = identifier
                }
            }
            if map[full] == nil {
                map[full] = identifier
            }
        }
        return map
    }()

    static func resolve(_ name: String) -> WorldZone? {
        let normalized = name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !normalized.isEmpty,
              let identifier = aliases[normalized] ?? ianaNames[normalized] else { return nil }
        return WorldZone(identifier: identifier)
    }
}
