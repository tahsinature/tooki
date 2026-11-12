import SwiftUI
import TookiKit

/// The left column: pinned snippets, then the rest grouped by when they were last used.
struct SnippetListView: View {
    let model: SnippetPanelModel
    let onCopy: () -> Void

    var body: some View {
        GroupedPanelList(
            sections: model.sections,
            selectedID: model.selectedSnippet?.id,
            onSelect: { model.selectedID = $0 },
            onDoubleClick: onCopy,
            onShowActions: model.actions.open,
            row: row
        )
    }

    private func row(_ snippet: Snippet, isSelected: Bool) -> some View {
        ResultRow(title: snippet.name, isSelected: isSelected) {
            Image(systemName: snippet.dynamic == nil ? "doc.text" : "function")
                .font(.system(size: 14))
                .foregroundStyle(PanelTheme.secondaryText)
        } trailing: {
            if !snippet.keyword.isEmpty {
                KeywordPill(keyword: snippet.keyword)
            }
            if snippet.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.secondaryText)
            }
        }
    }
}

/// The keyword that expands a snippet, e.g. `;date`.
struct KeywordPill: View {
    let keyword: String

    var body: some View {
        Text(keyword)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(PanelTheme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(PanelTheme.border, lineWidth: 0.5))
    }
}
