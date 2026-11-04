import SwiftUI

/// The ⌘K menu listing every action for the selected item, or the apps for "Open With…".
struct ClipboardActionsMenu: View {
    /// Shown above the rows, e.g. "Open With".
    let title: String?
    let actions: [ClipboardAction]
    let selection: Int
    @Binding var query: String
    let searchPrompt: String
    let onKey: (KeyPress) -> KeyPress.Result
    let onRun: (ClipboardAction.Kind) -> Void

    @FocusState private var isQueryFocused: Bool
    @ViewState private var rowsHeight: CGFloat = 0

    private static let maxListHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            // Sized to the rows, scrolling only past the maximum height.
            ScrollViewReader { proxy in
                ScrollView {
                    rows.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(rowsHeight, Self.maxListHeight))
                .onChange(of: selection, initial: true) { proxy.scrollTo(selection) }
            }
            Divider()
            TextField(searchPrompt, text: $query)
                .textFieldStyle(.plain)
                .focused($isQueryFocused)
                .onKeyPress(phases: [.down, .repeat], action: onKey)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .onAppear { isQueryFocused = true }
        .frame(width: 280)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
        .shadow(radius: 12)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            if actions.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button { onRun(action.kind) } label: { row(action, isSelected: index == selection) }
                    .buttonStyle(.plain)
                    .id(index)
            }
        }
        .padding(6)
    }

    private func row(_ action: ClipboardAction, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            icon(action.icon)
            Text(action.title).lineLimit(1)
            Spacer(minLength: 20)
            Text(action.shortcut).foregroundStyle(.secondary)
        }
        .foregroundStyle(action.isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func icon(_ icon: ClipboardAction.Icon) -> some View {
        switch icon {
        case .symbol(let name): Image(systemName: name).frame(width: 16)
        case .app(let image): Image(nsImage: image).resizable().frame(width: 16, height: 16)
        }
    }
}
