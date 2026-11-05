import SwiftUI
import TookiKit

/// Copy as the main button, with Paste, Drag and More as icons beside it.
struct ClipboardActionBar: View {
    let item: ClipboardItem
    let targetAppName: String?
    let onAction: (ClipboardAction.Kind) -> Void
    let onShowActions: () -> Void
    let onDropped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onAction(.copy) } label: {
                HStack(spacing: 8) {
                    Text("Copy to Clipboard")
                    Image(systemName: "return")
                        .font(.caption.weight(.semibold))
                        .opacity(0.75)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!item.canBeUsed)

            IconButton(systemImage: "arrow.up.forward.app", help: "Paste to \(targetAppName ?? "Active App") (⌘↵)") {
                onAction(.paste)
            }
            .disabled(!item.canBeUsed)

            // A finished drop works like a paste, so the panel closes.
            ClipboardDragButton(item: item, onDropped: onDropped)
                .frame(width: 32, height: 32)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .disabled(!item.canBeUsed)

            IconButton(systemImage: "ellipsis", help: "More actions (⌘K)", action: onShowActions)
        }
    }
}

private struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .frame(width: 32, height: 32)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
