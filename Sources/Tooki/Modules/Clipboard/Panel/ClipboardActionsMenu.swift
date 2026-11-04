import SwiftUI

/// The ⌘K menu listing every action for the selected item.
struct ClipboardActionsMenu: View {
    let actions: [ClipboardAction]
    let selection: Int
    let onRun: (ClipboardAction.Kind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button { onRun(action.kind) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon).frame(width: 16)
                        Text(action.title)
                        Spacer(minLength: 20)
                        Text(action.shortcut).foregroundStyle(.secondary)
                    }
                    .foregroundStyle(action.isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(index == selection ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(width: 280)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
        .shadow(radius: 12)
    }
}
