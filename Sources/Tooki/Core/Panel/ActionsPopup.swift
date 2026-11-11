import SwiftUI

/// Something the ⌘K popup can list.
protocol PanelActionItem: Identifiable {
    var title: String { get }
    var icon: PanelIcon { get }
    /// Shown as key caps at the end of the row, e.g. "⌘↵". Empty shows none.
    var shortcut: String { get }
    var isDestructive: Bool { get }
}

/// The ⌘K popup: a short list of actions with a filter field at the bottom.
/// It grows out of the bottom-right corner, above the `BottomActionBar`.
struct ActionsPopup<Action: PanelActionItem>: View {
    /// Shown above the rows, e.g. the selected item's name or "Open With".
    let title: String?
    let actions: [Action]
    let selection: Int
    @Binding var query: String
    let searchPrompt: String
    let onKey: (KeyPress) -> KeyPress.Result
    let onRun: (Action) -> Void

    @FocusState private var isQueryFocused: Bool
    @ViewState private var rowsHeight: CGFloat = 0

    static var width: CGFloat { 350 }
    private static var maxListHeight: CGFloat { 202 }

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
            PanelTheme.popupDivider.frame(height: 1)
            TextField("", text: $query, prompt: Text(searchPrompt).foregroundStyle(PanelTheme.tertiaryText))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(PanelTheme.primaryText)
                .focused($isQueryFocused)
                .onKeyPress(phases: [.down, .repeat], action: onKey)
                .padding(.horizontal, 12)
                .frame(height: 41)
        }
        .onAppear { isQueryFocused = true }
        .frame(width: Self.width)
        .popupSurface()
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(PanelTheme.labelFont)
                    .foregroundStyle(PanelTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            if actions.isEmpty {
                Text("No matching actions")
                    .font(.system(size: 13))
                    .foregroundStyle(PanelTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: PanelTheme.rowHeight)
            }
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                row(action, isSelected: index == selection)
                    .onTapGesture { onRun(action) }
                    .id(index)
            }
        }
        .padding(8)
    }

    private func row(_ action: Action, isSelected: Bool) -> some View {
        let color = action.isDestructive ? PanelTheme.danger : PanelTheme.primaryText
        return ResultRow(title: action.title, isSelected: isSelected, titleColor: color) {
            PanelIconView(icon: action.icon, size: PanelTheme.rowIconSize)
                .foregroundStyle(color)
        } trailing: {
            if !action.shortcut.isEmpty {
                Keycap(shortcut: action.shortcut)
            }
        }
    }
}

extension View {
    /// The blurred, bordered card the ⌘K and filter popups float on.
    func popupSurface(cornerRadius: CGFloat = PanelTheme.cornerRadius) -> some View {
        background {
            ZStack {
                VisualEffectBackground(material: .hudWindow)
                PanelTheme.popupBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(PanelTheme.popupBorder)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: -8, y: 10)
    }
}
