import SwiftUI

/// How a verdict is shown: icon, color, a headline and supporting lines.
extension DetectiveCheck.Verdict {
    var symbol: String {
        switch self {
        case .reachedApp: "checkmark.circle.fill"
        case .taken: "hand.raised.fill"
        case .takenByUnknown: "questionmark.circle.fill"
        case .lookedUp: "shield.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .reachedApp: .green
        case .taken: .orange
        case .takenByUnknown: .red
        case .lookedUp: .blue
        }
    }

    var headline: String {
        switch self {
        case .reachedApp(let app, _):
            "Reached \(app)"
        case .taken(let owners):
            "Taken by \(Self.names(of: owners))"
        case .takenByUnknown:
            "Taken before reaching any app"
        case .lookedUp(let owners, let app, let menuItem):
            owners.isEmpty && menuItem == nil
                ? "No known owner"
                : "Assigned to \(Self.names(of: owners, plus: menuItem == nil ? nil : app))"
        }
    }

    var details: [String] {
        switch self {
        case .reachedApp(let app, let menuItem):
            menuItem.map { ["Menu item: \($0)"] } ?? ["Nothing took it on the way. \(app) may use it without a menu item, or ignore it."]
        case .taken(let owners):
            owners.map(Self.describe)
        case .takenByUnknown(let frontApp, let interceptors):
            ["It never reached \(frontApp). Most likely another app's global hotkey."]
                + (interceptors.isEmpty ? [] : ["Apps that can intercept keys: " + interceptors.joined(separator: ", ")])
        case .lookedUp(let owners, let app, let menuItem):
            owners.isEmpty && menuItem == nil
                ? ["Tooki doesn't know this one. Choose Run Shortcut to test it live."]
                : owners.map(Self.describe) + (menuItem.map { ["\(app) menu: \($0)"] } ?? [])
        }
    }

    private static func describe(_ owner: KnownShortcut) -> String {
        "\(owner.owner): \(owner.detail)"
    }

    private static func names(of owners: [KnownShortcut], plus extra: String? = nil) -> String {
        var seen = Set<String>()
        let names = (owners.map(\.owner) + [extra].compactMap { $0 }).filter { seen.insert($0).inserted }
        return names.formatted(.list(type: .and))
    }
}

/// The latest check, shown big: key caps, verdict and details.
struct DetectiveResultView: View {
    let check: DetectiveCheck

    var body: some View {
        VStack(spacing: 10) {
            KeyCaps(symbols: check.combo.symbols, size: .large)
            Label(check.verdict.headline, systemImage: check.verdict.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(check.verdict.color)
            VStack(spacing: 2) {
                ForEach(check.verdict.details, id: \.self) { line in
                    Text(line)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .textSelection(.enabled)
        }
    }
}

/// An earlier check, in one line.
struct DetectiveHistoryRow: View {
    let check: DetectiveCheck

    var body: some View {
        HStack(spacing: 10) {
            KeyCaps(symbols: check.combo.symbols)
            Image(systemName: check.verdict.symbol)
                .foregroundStyle(check.verdict.color)
            Text(check.verdict.headline)
                .lineLimit(1)
            Spacer()
            Text(check.date, style: .time)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .help(check.verdict.details.joined(separator: "\n"))
    }
}
