import Foundation

/// Compares release versions like `0.6.0` and `v0.10.1` number by number.
public enum AppVersion {
    public static func isNewer(_ version: String, than current: String) -> Bool {
        let new = numbers(version), old = numbers(current)
        for index in 0..<max(new.count, old.count) {
            let a = index < new.count ? new[index] : 0
            let b = index < old.count ? old[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// `v1.2.3` without the `v`, as shown to people.
    public static func plain(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func numbers(_ version: String) -> [Int] {
        plain(version).split(separator: ".").map { Int($0) ?? 0 }
    }
}
