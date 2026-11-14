import SwiftUI
import TookiKit

/// A searchable emoji grid in the same frame as the other panels.
struct EmojiPanelView: View {
    @Bindable var model: EmojiPanelModel
    let onRun: (EmojiAction) -> Void
    let onCancel: () -> Void
    @ViewState private var navigation = PanelKeyboardNavigation()

    var body: some View {
        PanelLayout {
            SearchHeader(placeholder: "Search emoji…", query: $model.query,
                         isSearchActive: !(model.isShowingActions && model.selected != nil), onKey: handleKey) {
                EmptyView()
            }
        } content: {
            content
        } footer: {
            BottomActionBar(
                title: model.selected?.name.capitalized ?? "Emoji",
                icon: .symbol("face.smiling"),
                primaryActionTitle: model.selected == nil ? nil : "Copy Emoji",
                onPrimaryAction: { onRun(.copy) },
                onShowActions: { model.isShowingActions.toggle() }
            )
        }
        .actionsPopup(isPresented: model.isShowingActions, onDismiss: { model.isShowingActions = false }) {
            if let emoji = model.selected {
                ActionsPopup(
                    title: "\(emoji.character)  \(emoji.name.capitalized)",
                    actions: EmojiAction.allCases,
                    selection: model.actionSelection,
                    query: .constant(""),
                    searchPrompt: "Search for actions…",
                    onKey: handleKey,
                    onRun: onRun
                )
            }
        }
        .environment(\.panelKeyboardNavigation, navigation)
    }

    @ViewBuilder
    private var content: some View {
        if model.results.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else {
            EmojiGrid(model: model, onPick: { onRun(.copy) })
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let area: PanelScrollArea = model.isShowingActions ? .actions : .results
        let offset = PanelKeyboardNavigation.offset(
            for: press.key, modifiers: press.modifiers,
            pageSize: model.isShowingActions ? navigation.actionsPageSize : navigation.resultsPageSize,
            stride: model.isShowingActions ? 1 : EmojiPanelModel.columns
        ) ?? (press.key == .leftArrow ? -1 : (press.key == .rightArrow ? 1 : nil))
        if let offset {
            if model.isShowingActions {
                model.actionSelection = min(max(model.actionSelection + offset, 0), EmojiAction.allCases.count - 1)
            } else {
                model.moveSelection(by: offset)
            }
            navigation.moved(in: area)
            return .handled
        }
        guard press.phase == .down else { return .ignored }
        switch press.key {
        case .escape:
            if model.isShowingActions { model.isShowingActions = false } else { onCancel() }
        case .return:
            if model.isShowingActions {
                onRun(EmojiAction.allCases[model.actionSelection])
            } else {
                onRun(press.modifiers.contains(.command) ? .paste : .copy)
            }
        default:
            guard press.modifiers.contains(.command), press.characters.lowercased() == "k" else { return .ignored }
            model.isShowingActions.toggle()
        }
        return .handled
    }
}

private struct EmojiGrid: View {
    let model: EmojiPanelModel
    let onPick: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: EmojiPanelModel.columns)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // One grid for all sections: grids nested in a lazy stack misjudge their height,
                // which stopped scrolling before the last rows.
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(model.sections.enumerated()), id: \.element.id) { index, section in
                        SwiftUI.Section {
                            ForEach(section.emoji) { emoji in
                                cell(emoji, sectionID: section.id)
                            }
                        } header: {
                            SectionHeader(title: section.title, isFirst: index == 0)
                        }
                    }
                }
                .padding(PanelTheme.listInset)
                .panelScrollContent()
            }
            .panelSelectionScrolling(
                proxy: proxy, selection: model.selected.map { cellID($0, in: sectionOfSelection) },
                first: model.sections.first.flatMap { section in section.emoji.first.map { cellID($0, in: section.id) } },
                last: model.sections.last.flatMap { section in section.emoji.last.map { cellID($0, in: section.id) } },
                rowHeight: 60, columns: EmojiPanelModel.columns
            )
        }
    }

    /// The same emoji can appear in "Recently Used" and in its category, so cells are keyed by both.
    private func cellID(_ emoji: Emoji, in sectionID: String) -> String {
        "\(sectionID)/\(emoji.id)"
    }

    private var sectionOfSelection: String {
        var start = 0
        for section in model.sections {
            if model.selection < start + section.emoji.count { return section.id }
            start += section.emoji.count
        }
        return ""
    }

    private func cell(_ emoji: Emoji, sectionID: String) -> some View {
        let isSelected = sectionID == sectionOfSelection && emoji.id == model.selected?.id
        return Text(emoji.character)
            .font(.system(size: 30))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: PanelTheme.rowRadius)
                        .fill(PanelTheme.selectedBackground)
                        .overlay(RoundedRectangle(cornerRadius: PanelTheme.rowRadius).strokeBorder(PanelTheme.selectedRim))
                }
            }
            .contentShape(Rectangle())
            .help(emoji.name.capitalized)
            .id(cellID(emoji, in: sectionID))
            .onTapGesture {
                if let index = flatIndex(of: emoji, in: sectionID) { model.selection = index }
                onPick()
            }
    }

    private func flatIndex(of emoji: Emoji, in sectionID: String) -> Int? {
        var start = 0
        for section in model.sections {
            if section.id == sectionID {
                return section.emoji.firstIndex(of: emoji).map { start + $0 }
            }
            start += section.emoji.count
        }
        return nil
    }
}
