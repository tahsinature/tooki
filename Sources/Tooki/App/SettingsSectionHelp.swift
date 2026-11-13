import SwiftUI

/// A standard information button next to a section title, with selectable help in a popover.
struct SettingsSectionHelp<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewState private var showsHelp = false

    var body: some View {
        Button(title, systemImage: "info.circle") { showsHelp = true }
            .labelStyle(.iconOnly)
            .font(.system(size: 11))
            .foregroundStyle(SettingsTheme.tertiaryText)
            .buttonStyle(.plain)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .help(title)
            .accessibilityHint("Opens an explanation")
            .popover(isPresented: $showsHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(SettingsTheme.rowTitleFont.weight(.medium))
                    content.font(SettingsTheme.sidebarFont)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .foregroundStyle(SettingsTheme.primaryText)
                .padding(12)
                .frame(width: 320, alignment: .leading)
            }
    }
}
