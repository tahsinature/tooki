import SwiftUI

/// All settings pages use the same compact spacing and inherit the window's glass surface.
struct SettingsScrollPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) { content }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(SettingsTheme.pageInset)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .font(SettingsTheme.controlFont)
        .controlSize(.small)
        .buttonStyle(InteractionButtonStyle(
            restingFill: SettingsTheme.searchBackground,
            horizontalPadding: 9, verticalPadding: 4
        ))
    }
}
