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
            .background(color.gradient, in: .rect(cornerRadius: size * 0.24))
    }
}

/// A shared feature hero for the grouped settings pages.
struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        Section {
            FeatureHeader(page: page)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

/// A compact header leaves space for tools with list and editor columns.
struct InlinePageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 16) {
            IconTile(symbol: page.icon, color: SettingsTheme.accent, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(page.title).font(.title2.bold())
                Text(page.summary)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.secondaryText)
            }
        }
        .padding(.vertical, 8)
    }
}

extension View {
    func groupedCard() -> some View {
        background(SettingsTheme.surface, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SettingsTheme.border))
            .clipShape(.rect(cornerRadius: 12))
    }
}
