import SwiftUI

/// A group of rows with optional heading help and an action. Reference sections can collapse.
struct SettingsSection<Content: View, Footer: View>: View {
    let title: String?
    let collapsible: Bool
    let footerTitle: String
    let action: SettingsSectionAction?
    let hasContent: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    @ViewState private var isExpanded = false

    init(_ title: String? = nil, collapsible: Bool = false, footerTitle: String? = nil,
         action: SettingsSectionAction? = nil, hasContent: Bool = true,
         @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.collapsible = collapsible
        self.footerTitle = footerTitle ?? "About \(title ?? "these settings")"
        self.action = action
        self.hasContent = hasContent
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if collapsible {
                HStack(alignment: .top, spacing: 6) {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        if hasContent { SettingsGroupCard { content }.padding(.top, 6) }
                    } label: {
                        Text(title ?? "Settings").font(SettingsTheme.sectionFont)
                    }
                    .tint(SettingsTheme.secondaryText)
                    help
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(SettingsTheme.cardBackground, in: .rect(cornerRadius: SettingsTheme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: SettingsTheme.cardRadius).strokeBorder(SettingsTheme.cardBorder))
            } else {
                if title != nil || Footer.self != EmptyView.self || action != nil {
                    HStack(spacing: 5) {
                        if let title {
                            Text(title).font(SettingsTheme.sectionFont)
                                .foregroundStyle(SettingsTheme.secondaryText)
                        }
                        help
                        Spacer(minLength: 8)
                        if let action {
                            Button(action.title, systemImage: action.symbol, action: action.run)
                                .font(SettingsTheme.controlFont)
                        }
                    }
                }
                if hasContent { SettingsGroupCard { content } }
            }
        }
    }

    @ViewBuilder
    private var help: some View {
        if Footer.self != EmptyView.self {
            SettingsSectionHelp(title: footerTitle) { footer }
        }
    }
}

extension SettingsSection where Footer == EmptyView {
    init(_ title: String? = nil, collapsible: Bool = false, action: SettingsSectionAction? = nil,
         hasContent: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(title, collapsible: collapsible, action: action, hasContent: hasContent,
                  content: content) { EmptyView() }
    }
}
