import AppKit
import ShelfFeature
import SwiftUI
import TookiDesignSystem
import TookiKit
@testable import Tooki

extension VisualFixtures {
    func view(for scenario: VisualScenario) -> AnyView {
        switch scenario {
        case .rootSearch: AnyView(searchView())
        case .menuBarDuplicates:
            AnyView(searchView(items: duplicateMenuBarItems()))
        case .clipboard:
            AnyView(clipboardView())
        case .snippets:
            AnyView(SnippetPanelView(model: snippets(), onAction: { _ in }, onCancel: {}))
        case .snippetForm:
            AnyView(SnippetFormView(model: snippets(form: true), onBack: {}, onSave: {}))
        case .emoji:
            AnyView(EmojiPanelView(model: EmojiPanelModel(recentCharacters: ["😀", "🙏"]), onRun: { _ in }, onCancel: {}))
        case .emojiFilteredActions:
            AnyView(emojiActions())
        case .actionsPopup:
            AnyView(actionsPopup(empty: false))
        case .emptyActionsPopup:
            AnyView(actionsPopup(empty: true))
        case .filterPopup:
            AnyView(filterPopup())
        case .shelfManager:
            AnyView(ShelfManagerView(model: ShelfManagerModel(library: ShelfLibrary(initialShelves: [shelf])), onAction: { _ in }, onCancel: {}))
        case .floatingShelf:
            AnyView(FloatingShelfFixture(shelf: compactShelf()))
        case .conversionSettings:
            AnyView(conversionView(.settings))
        case .conversionPreparing:
            AnyView(conversionView(.converting))
        case .conversionReview:
            AnyView(conversionView(.review))
        case .conversionSaving:
            AnyView(conversionView(.saving))
        }
    }

    private func duplicateMenuBarItems() -> [SearchItem] {
        let source = (0..<6).map { index in
            MenuBarItem(element: nil, pid: -1, appName: "Stats", bundleID: "eu.exelban.Stats", identifier: nil,
                        label: "Stats", frame: CGRect(x: index * 30, y: 0, width: 20, height: 22),
                        windowID: CGWindowID(index + 1), eventPID: -1)
        }
        return MenuBarSearchItemFactory.items(from: source, boundary: 50) { _ in }
    }

    private func compactShelf() -> Shelf {
        let second = ShelfItem(fileURL: item.url)
        let shelf = Shelf(saved: SavedShelf(id: UUID(), name: "Compact rows", lastUsed: now, items: [item, second]))
        shelf.selection = [item.id]
        return shelf
    }

    private func clipboardView() -> ClipboardPanelView {
        var pinned = ClipboardItem(text: "A pinned note", copiedAt: now)
        pinned.isPinned = true
        let items = [pinned, ClipboardItem(text: "A copied sentence for the detail preview.", copiedAt: now),
                     ClipboardItem(text: "#3B82F6", copiedAt: now)]
        let model = ClipboardPanelModel(history: ClipboardHistory(initialItems: items), targetAppName: "Notes")
        return ClipboardPanelView(model: model, onAction: { _ in }, onCancel: {}, onClose: {})
    }

    private func emojiActions() -> EmojiPanelView {
        let model = EmojiPanelModel(recentCharacters: ["😀"])
        model.isShowingActions = true
        model.actionQuery = "paste"
        return EmojiPanelView(model: model, onRun: { _ in }, onCancel: {})
    }

    private func actionsPopup(empty: Bool) -> some View {
        searchView().actionsPopup(isPresented: true, onDismiss: {}) {
            ActionsPopup(title: "Available actions", actions: empty ? [] : popupActions, selection: 0,
                         query: .constant(empty ? "no match" : ""), searchPrompt: "Search for actions…",
                         onKey: { _ in .ignored }, onRun: { _ in })
        }
    }

    private var popupActions: [ClipboardAction] {
        [ClipboardAction(kind: .copy, title: "Copy to Clipboard", icon: .symbol("doc.on.doc"), shortcut: "↵"),
         ClipboardAction(kind: .paste, title: "Paste to Notes", icon: .symbol("doc.on.clipboard"), shortcut: "⌘↵"),
         ClipboardAction(kind: .preview, title: "Preview", icon: .symbol("eye"), shortcut: "⌘Y"),
         ClipboardAction(kind: .openWith, title: "Open With…", icon: .symbol("arrow.up.forward.app")),
         ClipboardAction(kind: .addToShelf, title: "Add to Shelf…", icon: .symbol("tray.and.arrow.down")),
         ClipboardAction(kind: .togglePin, title: "Pin", icon: .symbol("pin")),
         ClipboardAction(kind: .delete, title: "Delete", icon: .symbol("trash"), shortcut: "⌃X")]
    }

    private func filterPopup() -> some View {
        searchView().overlay(alignment: .topTrailing) {
            FilterPopup(titles: ["All", "Applications", "Commands", "Menu Bar Items"], current: 0,
                        onPick: { _ in }, onClose: {})
                .padding(.top, 50)
                .padding(.trailing, 16)
        }
    }

    private func conversionView(_ phase: ShelfImageConversionFeature.Phase) -> some View {
        ShelfImageConversionView(model: conversion(phase: phase), width: ShelfMotion.width)
            .frame(width: ShelfMotion.width, height: 570, alignment: .top)
            .background(PanelTheme.barBackground)
    }
}
