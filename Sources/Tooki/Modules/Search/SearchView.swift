import SwiftUI

/// Asyar-style launcher: search on top, grouped results, actions along the bottom.
struct SearchView: View {
    @Bindable var model: SearchModel
    let onRun: (SearchAction, _ item: SearchItem) -> Void
    let onCancel: () -> Void
    let onOpenSettings: () -> Void

    @FocusState private var isSearchFocused: Bool
    @ViewState private var isFilterMenuOpen = false

    static let size = CGSize(width: 750, height: 480)
    private static let pageSize = 8

    var body: some View {
        VStack(spacing: 0) {
            SearchHeader(
                placeholder: model.placeholder,
                query: $model.query,
                isFocused: $isSearchFocused,
                onKey: handleKey
            ) {
                if !model.filterGroups.isEmpty {
                    PanelFilterMenu(
                        selection: $model.groupFilter,
                        isOpen: $isFilterMenuOpen,
                        allTitle: "All",
                        filterTitle: "Filter by Group",
                        options: model.filterGroups.map { ($0, $0.rawValue) }
                    )
                }
            }
            // Keeps the filter popup above the results.
            .zIndex(1)
            content
                .frame(maxHeight: .infinity)
                .simultaneousGesture(TapGesture().onEnded { isFilterMenuOpen = false })
            BottomActionBar(
                title: model.title,
                icon: model.icon,
                primaryActionTitle: model.selectedItem?.actionTitle,
                onPrimaryAction: { runSelected(copyOnly: false) },
                onShowActions: { model.isShowingActions.toggle() },
                badgeAction: FooterAction(title: "Open Tooki Settings", shortcut: "⌘,", run: onOpenSettings)
            )
        }
        .actionsPopup(isPresented: model.isShowingActions, onDismiss: { model.isShowingActions = false }) {
            if let item = model.selectedItem {
                ActionsPopup(
                    title: item.title,
                    actions: model.menuActions,
                    selection: model.actionSelection,
                    query: $model.menuQuery,
                    searchPrompt: "Search for actions…",
                    onKey: handleKey,
                    onRun: { onRun($0, item) }
                )
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .panelSurface()
        .onAppear { Task { isSearchFocused = true } }
        .onChange(of: model.isShowingActions) { _, isShowing in
            if !isShowing { isSearchFocused = true }
        }
        .onChange(of: isFilterMenuOpen) { _, isOpen in
            if !isOpen { isSearchFocused = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.results.isEmpty {
            ContentUnavailableView.search(text: model.query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SearchResultList(model: model, onRun: { runSelected(copyOnly: false) })
        }
    }

    private func runSelected(copyOnly: Bool) {
        guard let item = model.selectedItem else { return }
        let actions = model.menuActions
        let action = copyOnly ? actions.first { $0.id == "copy" } : actions.first
        if let action { onRun(action, item) }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let offset = navigationOffset(for: press.key) {
            if model.isShowingActions {
                model.moveActionSelection(by: offset)
            } else {
                model.moveSelection(by: offset)
            }
            return .handled
        }
        guard press.phase == .down else { return .ignored }
        switch press.key {
        case .escape:
            if model.isShowingActions {
                model.isShowingActions = false
            } else {
                onCancel()
            }
        case .return:
            if model.isShowingActions {
                if let action = model.selectedMenuAction, let item = model.selectedItem { onRun(action, item) }
            } else {
                runSelected(copyOnly: press.modifiers.contains(.command))
            }
        default:
            guard press.modifiers.contains(.command) else { return .ignored }
            switch press.characters.lowercased() {
            case "k": model.isShowingActions.toggle()
            case ",": onOpenSettings()
            case "p" where !model.filterGroups.isEmpty:
                model.isShowingActions = false
                isFilterMenuOpen.toggle()
            default: return .ignored
            }
        }
        return .handled
    }

    private func navigationOffset(for key: KeyEquivalent) -> Int? {
        switch key {
        case .upArrow: -1
        case .downArrow: 1
        case .pageUp: -Self.pageSize
        case .pageDown: Self.pageSize
        default: nil
        }
    }
}

private struct SearchResultList: View {
    let model: SearchModel
    let onRun: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                        SectionHeader(title: section.title, isFirst: sectionIndex == 0, isCompact: true)
                        ForEach(section.items) { item in
                            row(item)
                        }
                    }
                }
                .padding(PanelTheme.listInset)
            }
            .onChange(of: model.selection) { _, _ in
                if let id = model.selectedItem?.id { proxy.scrollTo(id) }
            }
        }
    }

    private func row(_ item: SearchItem) -> some View {
        let isSelected = item.id == model.selectedItem?.id
        return Group {
            if let calculation = item.calculation {
                CalculatorCard(calculation: calculation, isSelected: isSelected)
            } else {
                ResultRow(title: item.title, subtitle: item.subtitle, isSelected: isSelected) {
                    PanelIconView(icon: item.icon)
                        .foregroundStyle(PanelTheme.primaryText)
                } trailing: {
                    if let keyword = item.keyword, !keyword.isEmpty {
                        Text(keyword)
                            .font(PanelTheme.monoFont)
                            .foregroundStyle(PanelTheme.secondaryText)
                    }
                    Text(item.kind)
                        .font(.system(size: 13))
                        .foregroundStyle(PanelTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .id(item.id)
        .overlay {
            SecondaryClickArea {
                if let index = model.results.firstIndex(where: { $0.id == item.id }) {
                    model.selection = index
                    model.isShowingActions = true
                }
            }
        }
        .onTapGesture {
            if let index = model.results.firstIndex(where: { $0.id == item.id }) { model.selection = index }
            onRun()
        }
    }
}
