import AppKit
import SwiftUI

/// A copy target with a reserved confirmation slot, so feedback never shifts the row.
struct CopyButton<Content: View>: View {
    let text: String
    let label: String
    @ViewBuilder let content: Content
    @ViewState private var copied = false
    @ViewState private var copyGeneration = 0
    @ViewState private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            copied = NSPasteboard.general.setString(text, forType: .string)
            copyGeneration += 1
        } label: {
            HStack(spacing: 8) {
                content
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text("Copied").opacity(copied ? 1 : 0)
                }
                .font(.caption)
                .foregroundStyle(copied ? Color.green : Color.secondary)
                .opacity(copied || isHovered ? 1 : 0)
                .accessibilityHidden(true)
            }
        }
        .buttonStyle(InteractionButtonStyle(horizontalPadding: 6, verticalPadding: 5))
        .onHover { isHovered = $0 }
        .help("Copy \(label)")
        .accessibilityLabel("Copy \(label)")
        .accessibilityValue(copied ? "Copied" : "")
        .task(id: copyGeneration) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            copied = false
        }
    }
}
