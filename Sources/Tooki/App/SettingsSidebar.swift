import SwiftUI

struct SettingsSidebar: View {
    @Bindable var navigation: SettingsNavigation
    let updater: Updater
    var needsAttention = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reserve room for the native traffic lights in the unified title bar.
            Color.clear.frame(height: 54)
            searchField.padding(.horizontal, 12).padding(.bottom, 16)
            if navigation.query.isEmpty {
                SettingsAppIdentity(updater: updater) { navigation.page = .about }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 23)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if navigation.filteredPages.isEmpty {
                        Text("No settings found")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.top, 3)
                    } else {
                        ForEach(SettingsPage.Group.allCases, id: \.self) { group in
                            let pages = navigation.filteredPages.filter { $0.group == group }
                            if !pages.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    if navigation.query.isEmpty, !group.rawValue.isEmpty {
                                        Text(group.rawValue)
                                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
                                            .padding(.leading, 10).padding(.bottom, 4)
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
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 228)
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
        .font(.system(size: 12))
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(SettingsTheme.searchBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.5) : SettingsTheme.separator))
    }
}
