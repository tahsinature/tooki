import AppKit
import SwiftUI

/// One label and value in a `MetadataList`.
struct MetadataItem: Identifiable {
    let label: String
    let value: String?
    var icon: NSImage?
    /// Hover text, e.g. the exact date behind "5 minutes ago".
    var help: String?

    var id: String { label }
}

/// A compact block of label and value rows under a detail preview. Rows without a value are skipped.
struct MetadataList: View {
    var title: String?
    let items: [MetadataItem]

    var body: some View {
        let visible = items.filter { !($0.value ?? "").isEmpty }
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
            }
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                row(item, isStriped: index.isMultiple(of: 2))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func row(_ item: MetadataItem, isStriped: Bool) -> some View {
        HStack(spacing: 8) {
            Text(item.label)
                .foregroundStyle(PanelTheme.secondaryText)
            Spacer(minLength: 8)
            if let icon = item.icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(item.value ?? "")
                .foregroundStyle(PanelTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(item.help ?? item.value ?? "")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 6)
        .frame(minHeight: 24)
        .background(isStriped ? PanelTheme.tertiaryBackground : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
