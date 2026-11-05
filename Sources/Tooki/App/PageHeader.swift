import SwiftUI

/// A white symbol on a colored rounded square, like the icons in System Settings.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// The card at the top of every settings page: big icon, title and a one-line summary.
/// Place it as the first section of a grouped `Form`.
struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        Section {
            VStack(spacing: 6) {
                IconTile(symbol: page.icon, color: page.color, size: 52)
                    .padding(.bottom, 4)
                Text(page.title)
                    .font(.title2.bold())
                Text(page.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

/// A slim, left-aligned header for pages that fill the window with their own layout instead of a `Form`.
struct InlinePageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: page.icon, color: page.color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title).font(.title3.bold())
                Text(page.summary).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    /// A rounded panel matching the sections of a grouped `Form`.
    func groupedCard() -> some View {
        background(.fill.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.separator.opacity(0.6)))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
