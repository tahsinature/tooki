import SwiftUI
import TookiDesignSystem

typealias ViewState<Value> = SwiftUI.State<Value>

struct ComponentGalleryView: View {
    @ViewState private var darkAppearance = true
    @ViewState private var query = ""
    @ViewState private var selected = "Today"
    @ViewState private var filter: String?
    @ViewState private var actions = ActionsMenu<GalleryAction>()
    @ViewState private var navigation = PanelKeyboardNavigation()
    @ViewState private var status = "Select a row or try the footer buttons."

    let titles: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tooki components").font(.largeTitle.bold())
                        Text("Production components, isolated from your data.").foregroundStyle(.secondary)
                        Text("\(titles.count.formatted()) sample entries").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Dark appearance", isOn: $darkAppearance).toggleStyle(.switch)
                }
                panel
                Text(status).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("gallery.status")
                HStack(alignment: .top, spacing: 24) {
                    rowStates.frame(maxWidth: .infinity)
                    tokens.frame(maxWidth: .infinity)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(darkAppearance ? Color(white: 0.08) : Color(white: 0.94))
        .preferredColorScheme(darkAppearance ? .dark : .light)
        .onAppear { actions.rootActions = { GalleryAction.allCases } }
        .onChange(of: query) { selected = filteredTitles.first ?? "" }
        .onChange(of: filter) { selected = filteredTitles.first ?? "" }
    }

    private var filteredTitles: [String] {
        titles.filter { (query.isEmpty || $0.localizedCaseInsensitiveContains(query)) && (filter == nil || $0 == "Today") }
    }

    private var panel: some View {
        ListDetailPanel(
            placeholder: "Search sample entries…", query: $query, actions: actions, navigation: navigation,
            footer: ListDetailFooter(title: "Component Gallery", icon: .symbol("square.stack.3d.up"), primaryActionTitle: "Copy"),
            hasItems: !filteredTitles.isEmpty,
            onMove: moveSelection,
            onReturn: { _ in status = "Copy selected: \(selected)" },
            onRunAction: { action in status = "\(action.title): \(selected)"; actions.close() },
            onShortcut: { _ in .ignored },
            onCancel: { status = "Close requested" }
        ) { isFilterOpen in
            PanelFilterMenu(selection: $filter, isOpen: isFilterOpen, allTitle: "All entries", filterTitle: "Filter entries",
                            options: [("pinned", "Pinned only")])
        } list: {
            GroupedPanelList(
                sections: [PanelListSection(title: "Pinned", items: filteredTitles.filter { $0 == "Today" }.map(GalleryItem.init)),
                           PanelListSection(title: "Earlier", items: filteredTitles.filter { $0 != "Today" }.map(GalleryItem.init))],
                selectedID: selected,
                onSelect: { selected = $0 },
                onDoubleClick: { status = "Copy selected: \(selected)" },
                onShowActions: actions.open
            ) { item, isSelected in
                ResultRow(title: item.id, isSelected: isSelected, isDimmed: item.id == "Unavailable file") {
                    Image(systemName: "doc.text")
                } trailing: {
                    if item.id == "Today" { Image(systemName: "pin.fill") }
                }
            }
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                Text(selected).font(.title2.bold())
                Text("Production list-detail layout, grouping, keyboard navigation, filter menu and actions popup.")
                    .foregroundStyle(PanelTheme.secondaryText)
                Spacer()
                Text("Try ↑↓, ⌘↑↓, Page Up/Down, ⌘P and ⌘K.").font(PanelTheme.labelFont)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } emptyState: {
            ContentUnavailableView.search(text: query)
        }
        .frame(maxWidth: .infinity)
    }

    private var rowStates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Row and shortcut states").font(.headline)
            ForEach(["Default", "Selected", "Unavailable", "Destructive"], id: \.self) { title in
                ResultRow(title: title, isSelected: title == "Selected", isDimmed: title == "Unavailable",
                          titleColor: title == "Destructive" ? PanelTheme.danger : PanelTheme.primaryText) {
                    Image(systemName: title == "Destructive" ? "trash" : "doc.text")
                } trailing: { Keycap(shortcut: "⌘K") }
            }
            Button("Interactive button") { status = "Button activated" }
                .buttonStyle(InteractionButtonStyle(horizontalPadding: 12, verticalPadding: 8))
        }
    }

    private var tokens: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Semantic colors").font(.headline)
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                HStack {
                    RoundedRectangle(cornerRadius: 6).fill(swatch.1).frame(width: 32, height: 24)
                    Text(swatch.0).font(.callout)
                }
            }
            Text("Panel: 750 × 480 · Row: 38 · List inset: 8")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var swatches: [(String, Color)] {
        [("Primary text", PanelTheme.primaryText), ("Secondary text", PanelTheme.secondaryText),
         ("Selection", PanelTheme.selectedBackground), ("Hover", PanelTheme.hoverBackground),
         ("Accent", PanelTheme.accent), ("Destructive", PanelTheme.danger)]
    }

    private func moveSelection(_ offset: Int) {
        guard !filteredTitles.isEmpty else { return }
        let current = filteredTitles.firstIndex(of: selected) ?? 0
        let bounded = max(-filteredTitles.count, min(offset, filteredTitles.count))
        selected = filteredTitles[min(max(current + bounded, 0), filteredTitles.count - 1)]
    }
}
