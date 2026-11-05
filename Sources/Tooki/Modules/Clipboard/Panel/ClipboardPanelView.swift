import SwiftUI
import TookiKit

/// Raycast-style clipboard history: list on the left, preview and information on the right.
struct ClipboardPanelView: View {
    @Bindable var model: ClipboardPanelModel
    let onAction: (ClipboardAction.Kind) -> Void
    let onCancel: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                ClipboardListView(model: model, onPaste: { onAction(.paste) })
                    .frame(width: 320)
                Divider()
                if let item = model.selectedItem {
                    ClipboardDetailView(item: item)
                } else {
                    emptyState
                }
            }
            Divider()
            footer
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
                .padding(.trailing, 10)
                .padding(.bottom, 44)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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

    private var footer: some View {
        HStack(spacing: 10) {
            Label("Clipboard History", systemImage: "list.clipboard")
                .foregroundStyle(.secondary)
            Spacer()
            if let item = model.selectedItem {
                // A finished drop works like a paste, so the panel closes.
                ClipboardDragButton(item: item, onDropped: onCancel)
                    .disabled(!item.canBeUsed)
                Divider().frame(height: 14)
            }
            FooterButton(title: "Paste to \(model.targetAppName ?? "Active App")", shortcut: "↵") { onAction(.paste) }
                .disabled(model.selectedItem?.canBeUsed == false)
            Divider().frame(height: 14)
            FooterButton(title: "Actions", shortcut: "⌘K") { toggleActions() }
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .disabled(model.selectedItem == nil)
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
                onAction(command ? .copy : .paste)
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

private struct FooterButton: View {
    let title: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text(shortcut)
                    .font(.caption)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .buttonStyle(.plain)
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
