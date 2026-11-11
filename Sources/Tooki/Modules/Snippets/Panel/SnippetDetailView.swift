import SwiftUI
import TookiKit

/// The right column: the snippet's text as written, then its details.
struct SnippetDetailView: View {
    let snippet: Snippet
    let usage: LaunchHistory.Entry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                Text(snippet.text)
                    .font(PanelTheme.monoFont)
                    .lineSpacing(5)
                    .foregroundStyle(PanelTheme.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxHeight: .infinity)
            MetadataList(title: "Information", items: metadata)
        }
    }

    private var metadata: [MetadataItem] {
        [
            MetadataItem(label: "Name", value: snippet.name),
            MetadataItem(label: "Keyword", value: snippet.keyword.isEmpty ? nil : snippet.keyword),
            MetadataItem(label: "Collection", value: snippet.collection.isEmpty ? nil : snippet.collection),
            MetadataItem(label: "Characters", value: snippet.text.count.formatted()),
            MetadataItem(label: "Times Used", value: (usage?.count ?? 0).formatted()),
            dateItem("Last Used", usage?.lastUsed),
            dateItem("Modified", snippet.modifiedAt),
            dateItem("Created", snippet.createdAt),
        ]
    }

    private func dateItem(_ label: String, _ date: Date?) -> MetadataItem {
        MetadataItem(
            label: label,
            value: date.map { Self.relativeFormatter.localizedString(for: $0, relativeTo: Date()) },
            help: date?.formatted(date: .abbreviated, time: .shortened)
        )
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
