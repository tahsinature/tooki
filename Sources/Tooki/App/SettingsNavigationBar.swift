import SwiftUI

struct SettingsNavigationBar: View {
    let navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 0) {
                Button("Back", systemImage: "chevron.left", action: navigation.goBack)
                    .disabled(navigation.backHistory.isEmpty)
                    .keyboardShortcut("[", modifiers: .command)
                Rectangle().fill(SettingsTheme.separator).frame(width: 1, height: 17)
                Button("Forward", systemImage: "chevron.right", action: navigation.goForward)
                    .disabled(navigation.forwardHistory.isEmpty)
                    .keyboardShortcut("]", modifiers: .command)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SettingsHistoryButtonStyle())
            .padding(3)
            .background(SettingsTheme.searchBackground, in: Capsule())
            .overlay(Capsule().strokeBorder(SettingsTheme.separator))
            Text(navigation.page.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 22)
        .frame(height: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(SettingsTheme.separator).frame(height: 1) }
    }
}

private struct SettingsHistoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(width: 26, height: 26)
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : .clear, in: Circle())
            .contentShape(Circle())
    }
}
