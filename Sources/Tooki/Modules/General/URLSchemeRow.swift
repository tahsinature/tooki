import AppKit
import SwiftUI

/// A `tooki://` link and what to tell people about it.
struct URLSchemeLink: Identifiable {
    let title: String
    /// The text copied when the row is clicked.
    let copyText: String
    /// Shown in the row. Defaults to `copyText`.
    var label: String?
    let details: String
    let examples: [String]

    var id: String { title }
}

/// One line per link: click it to copy, or open the info popover for details and examples.
struct URLSchemeRow: View {
    let link: URLSchemeLink
    @ViewState private var showsInfo = false

    var body: some View {
        HStack(spacing: 8) {
            CopyableText(text: link.copyText, label: link.label ?? link.copyText)
            Text(link.title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button("About \(link.title)", systemImage: "info.circle") {
                showsInfo.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(InteractionButtonStyle(horizontalPadding: 5, verticalPadding: 5))
            .help("What this does, with examples")
            .popover(isPresented: $showsInfo, arrowEdge: .trailing) {
                URLSchemeInfo(link: link)
            }
        }
    }
}

private struct URLSchemeInfo: View {
    let link: URLSchemeLink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(link.title).font(.headline)
            Text(link.details)
                .fixedSize(horizontal: false, vertical: true)
            Text(link.examples.count == 1 ? "Example" : "Examples")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(link.examples, id: \.self) { example in
                CopyableText(text: example, label: example)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
            }
            Text("Click any example to copy it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420)
    }
}
