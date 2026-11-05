import SwiftUI
import TookiKit

/// Raycast-style clipboard history: list on the left, preview, stats and actions on the right.
struct ClipboardPanelView: View {
    @Bindable var model: ClipboardPanelModel
    let onAction: (ClipboardAction.Kind) -> Void
    let onCancel: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                ClipboardListView(model: model, onCopy: { onAction(.copy) })
                    .frame(width: 320)
                if let item = model.selectedItem {
                    ClipboardDetailView(
                        item: item,
                        targetAppName: model.targetAppName,
                        onAction: onAction,
                        onShowActions: toggleActions,
                        onDropped: onCancel
                    )
                } else {
                    emptyState
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if model.isShowingActions, model.selectedItem != nil {
                ClipboardActionsMenu(
                    title: model.openWithActions == nil ? nil : "Open With",
                    actions: model.menuActions,
                    selection: model.actionSelection,
                    query: $model.menuQuery,
                    searchPrompt: model.openWithActions == nil ? "Search for actions…" : "Search applications…",
                    onKey: handleKey,
                    onRun: onAction
                )
                .padding(.trailing, 18)
                .padding(.bottom, 56)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
        .onAppear { isSearchFocused = true }
        .onChange(of: model.isShowingActions) { _, isShowing in
            if !isShowing { isSearchFocused = true }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField("Type to filter entries…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onKeyPress(phases: [.down, .repeat], action: handleKey)
            Picker("Type", selection: $model.typeFilter) {
                Text("All Types").tag(ClipboardContentType?.none)
                Divider()
                ForEach(ClipboardContentType.allCases, id: \.self) { type in
                    Text(type.pluralLabel).tag(Optional(type))
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        Text(model.query.isEmpty && model.typeFilter == nil ? "Nothing copied yet" : "No matching entries")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleActions() {
        model.toggleActions()
    }

    private static let pageSize = 8

    private var selectedMenuAction: ClipboardAction? {
        let actions = model.menuActions
        return actions.indices.contains(model.actionSelection) ? actions[model.actionSelection] : nil
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let offset = navigationOffset(for: press.key) {
            moveSelection(by: offset)
            return .handled
        }
        // Holding Return or a shortcut must not run it repeatedly.
        guard press.phase == .down else { return .ignored }
        let command = press.modifiers.contains(.command)
        switch press.key {
        case .escape:
            if !model.dismissMenu() { onCancel() }
        case .leftArrow where model.openWithActions != nil && model.menuQuery.isEmpty:
            _ = model.dismissMenu()
        case .rightArrow where model.isShowingActions && model.menuQuery.isEmpty && selectedMenuAction?.kind == .openWith:
            model.showOpenWith()
        case .return:
            if model.isShowingActions {
                if let action = selectedMenuAction { onAction(action.kind) }
            } else {
                onAction(command ? .paste : .copy)
            }
        default:
            return handleShortcut(press)
        }
        return .handled
    }

    private func handleShortcut(_ press: KeyPress) -> KeyPress.Result {
        let key = press.characters.lowercased()
        if press.modifiers.contains(.command), key == "k" {
            toggleActions()
        } else if press.modifiers.contains(.command), key == "o" {
            model.showOpenWith()
        } else if press.modifiers.contains(.command), key == "p" {
            onAction(.togglePin)
        } else if press.modifiers.contains(.control), key == "x" || press.characters == "\u{18}" {
            onAction(.delete)
        } else {
            return .ignored
        }
        return .handled
    }

    /// Arrows move one row, Page Up/Down a page, Home/End to the ends. These repeat while held.
    private func navigationOffset(for key: KeyEquivalent) -> Int? {
        switch key {
        case .upArrow: -1
        case .downArrow: 1
        case .pageUp: -Self.pageSize
        case .pageDown: Self.pageSize
        case .home: -Int.max / 2
        case .end: Int.max / 2
        default: nil
        }
    }

    private func moveSelection(by offset: Int) {
        if model.isShowingActions {
            model.actionSelection = max(min(model.actionSelection + offset, model.menuActions.count - 1), 0)
        } else {
            model.moveSelection(by: offset)
        }
    }
}

extension ClipboardContentType {
    var pluralLabel: String {
        switch self {
        case .text: "Text"
        case .link: "Links"
        case .color: "Colors"
        case .image: "Images"
        case .file: "Files"
        }
    }
}
