import SwiftUI

struct SettingsNavigationBar: View {
    let navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 10) {
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
            Text(navigation.page.title).font(SettingsTheme.sidebarFont).foregroundStyle(SettingsTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: SettingsTheme.navigationHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(SettingsTheme.separator).frame(height: 1) }
    }
}

private struct SettingsHistoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .frame(width: 22, height: 24)
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : .clear, in: Circle())
            .contentShape(Circle())
    }
}
