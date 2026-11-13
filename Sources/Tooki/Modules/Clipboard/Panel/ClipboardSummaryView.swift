import SwiftUI
import TookiKit

/// Two quiet lines below the preview: content details, then source and copy time.
struct ClipboardSummaryView: View {
    let item: ClipboardItem

    @ViewState private var fileSize: String?

    var body: some View {
        VStack(spacing: 14) {
            PanelTheme.popupDivider.frame(height: 1)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text(item.contentType.label)
                    Spacer(minLength: 0)
                    if let fileSize {
                        Text(fileSize)
                            .help("Size on disk")
                            .accessibilityLabel("Size: \(fileSize)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PanelTheme.primaryText)
                HStack(spacing: 12) {
                    if let detail = ClipboardMetadata.detail(for: item) {
                        Text(detail)
                            .help(detail)
                            .layoutPriority(1)
                    }
                    Spacer(minLength: 0)
                    Text(sourceAndTime)
                        .help(ClipboardMetadata.copyHistory(for: item))
                        .accessibilityLabel("\(sourceAndTime). \(ClipboardMetadata.copyHistory(for: item))")
                }
                .font(.system(size: 11))
                .foregroundStyle(PanelTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            }
        }
        .padding(16)
        .task(id: item.id) {
            fileSize = ClipboardMetadata.fileSize(of: item)
        }
    }

    private var sourceAndTime: String {
        [SourceApp.named(item.sourceApp)?.name, ClipboardMetadata.copiedDescription(for: item)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
