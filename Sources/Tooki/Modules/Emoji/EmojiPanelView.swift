import SwiftUI
import TookiKit

/// A searchable emoji grid in the same frame as the other panels.
struct EmojiPanelView: View {
    @Bindable var model: EmojiPanelModel
    let onRun: (EmojiAction) -> Void
    let onCancel: () -> Void

    @FocusState private var isSearchFocused: Bool

    static let size = CGSize(width: 750, height: 480)

    var body: some View {
        VStack(spacing: 0) {
            SearchHeader(placeholder: "Search emoji…", query: $model.query, isFocused: $isSearchFocused, onKey: handleKey) {
                EmptyView()
            }
            content
                .frame(maxHeight: .infinity)
            BottomActionBar(
                title: model.selected?.name.capitalized ?? "Emoji",
                icon: .symbol("face.smiling"),
                primaryActionTitle: model.selected == nil ? nil : "Paste Emoji",
                onPrimaryAction: { onRun(.paste) },
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
        .frame(width: Self.size.width, height: Self.size.height)
        .panelSurface()
        .onAppear { Task { isSearchFocused = true } }
        .onChange(of: model.isShowingActions) { _, isShowing in
            if !isShowing { isSearchFocused = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.results.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else {
            EmojiGrid(model: model, onPaste: { onRun(.paste) })
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let columns = EmojiPanelModel.columns
        let page = columns * EmojiPanelModel.pageRows
        let offset: Int? = switch press.key {
        case .leftArrow: -1
        case .rightArrow: 1
        case .upArrow: -columns
        case .downArrow: columns
        case .pageUp: -page
        case .pageDown: page
        case .home: -model.results.count
        case .end: model.results.count
        default: nil
        }
        if let offset {
            if model.isShowingActions {
                let step = offset > 0 ? 1 : -1
                model.actionSelection = min(max(model.actionSelection + step, 0), EmojiAction.allCases.count - 1)
            } else {
                model.moveSelection(by: offset)
            }
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
                onRun(press.modifiers.contains(.command) ? .copy : .paste)
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
    let onPaste: () -> Void

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
                            SectionHeader(title: section.title, isFirst: index == 0, isCompact: true)
                        }
                    }
                }
                .padding(PanelTheme.listInset)
            }
            .onChange(of: model.selection) { _, _ in
                if let emoji = model.selected { proxy.scrollTo(cellID(emoji, in: sectionOfSelection)) }
            }
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PanelTheme.selectedBackground)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PanelTheme.selectedRim))
                }
            }
            .contentShape(Rectangle())
            .help(emoji.name.capitalized)
            .id(cellID(emoji, in: sectionID))
            .onTapGesture {
                if let index = flatIndex(of: emoji, in: sectionID) { model.selection = index }
                onPaste()
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
