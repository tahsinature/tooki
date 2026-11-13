import SwiftUI

struct SettingsSidebar: View {
    @Bindable var navigation: SettingsNavigation
    let updater: Updater
    var needsAttention = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reserve room for the native traffic lights in the unified title bar.
            Color.clear.frame(height: SettingsTheme.navigationHeight)
            searchField.padding(.horizontal, 8).padding(.bottom, 8)
            if navigation.query.isEmpty {
                SettingsAppIdentity(updater: updater) { navigation.page = .about }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if navigation.filteredPages.isEmpty {
                        Text("No settings found")
                            .font(SettingsTheme.sidebarFont).foregroundStyle(SettingsTheme.secondaryText)
                            .padding(.horizontal, 12).padding(.top, 3)
                    } else {
                        ForEach(SettingsPage.Group.allCases, id: \.self) { group in
                            let pages = navigation.filteredPages.filter { $0.group == group }
                            if !pages.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    if navigation.query.isEmpty, !group.rawValue.isEmpty {
                                        Text(group.rawValue)
                                            .font(SettingsTheme.metadataFont).foregroundStyle(SettingsTheme.tertiaryText)
                                            .padding(.leading, 8).padding(.top, 2).padding(.bottom, 5)
                                    }
                                    ForEach(pages) { page in
                                        SettingsSidebarRow(page: page, isSelected: navigation.page == page,
                                                           hasWarning: page == .general && needsAttention,
                                                           hasUpdate: page == .about && updater.shouldPrompt) { navigation.page = page }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .frame(width: SettingsTheme.sidebarWidth)
        .background(SettingsTheme.sidebarBackground)
        .overlay(alignment: .trailing) { Rectangle().fill(SettingsTheme.separator).frame(width: 1) }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField("Search settings…", text: $navigation.query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .accessibilityLabel("Search settings")
                .onKeyPress(.escape) {
                    guard !navigation.query.isEmpty else { return .ignored }
                    navigation.query = ""
                    return .handled
                }
            if !navigation.query.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { navigation.query = "" }
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .font(SettingsTheme.sidebarFont)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(SettingsTheme.searchBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.5) : SettingsTheme.separator))
    }
}
