import AppKit
import SwiftUI

/// A flat copy row. The small indicator has a fixed slot, so feedback never moves its content.
struct CopyButton<Content: View>: View {
    let text: String
    let label: String
    @ViewBuilder let content: Content
    @ViewState private var copied = false
    @ViewState private var copyGeneration = 0
    @ViewState private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 8) {
                content
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(SettingsTheme.rowDescriptionFont)
                    .foregroundStyle(copied ? Color.green : SettingsTheme.secondaryText)
                    .frame(width: 16, height: 16)
                    .opacity(copied || isHovered || isFocused ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
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

    private func copy() {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(text, forType: .string)
        copyGeneration += 1
    }
}
