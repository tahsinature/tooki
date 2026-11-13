import SwiftUI
import TookiKit

/// Clipboard-specific values displayed with the same metadata component as other tools.
struct ClipboardSummaryView: View {
    let item: ClipboardItem

    @ViewState private var fileSize: String?

    var body: some View {
        MetadataList(title: "Information", items: metadata)
            .task(id: item.id) {
                fileSize = ClipboardMetadata.fileSize(of: item)
            }
    }

    private var metadata: [MetadataItem] {
        let source = SourceApp.named(item.sourceApp)
        return [
            MetadataItem(label: "Type", value: item.contentType.label),
            MetadataItem(label: "Details", value: ClipboardMetadata.detail(for: item)),
            MetadataItem(label: "Size", value: fileSize, help: "Size on disk"),
            MetadataItem(label: "Source", value: source?.name, icon: source?.icon),
            MetadataItem(label: "Copied", value: ClipboardMetadata.copiedDescription(for: item),
                         help: ClipboardMetadata.copyHistory(for: item)),
        ]
    }
}
