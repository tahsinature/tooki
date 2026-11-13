import SwiftUI
import TookiKit

/// The Shortcut Detective card on the Shortcuts page: press any shortcut, see who takes it.
struct ShortcutDetectiveSection: View {
    @Bindable var detective: ShortcutDetective
    /// Tooki's own shortcuts, so they can be named too.
    let tookiShortcuts: [Shortcut]

    @ViewState private var couldNotStart = false

    var body: some View {
        SettingsSection("Shortcut Detective") {
            SettingsCardRow { header }
            if detective.isListening || !detective.checks.isEmpty {
                SettingsCardRow { stage }
            }
            SettingsCardRow { DetectiveModePicker(mode: $detective.testMode) }
            ForEach(detective.checks.dropFirst()) { check in
                SettingsCardRow { DetectiveHistoryRow(check: check) }
            }
        } footer: {
            Text("Tooki can name macOS, skhd and its own shortcuts, plus menu items of the app you're in. Other apps' global hotkeys show up as taken before reaching any app.")
        }
        .onDisappear(perform: detective.stop)
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "magnifyingglass", color: .indigo, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Find what takes a shortcut")
                    .font(SettingsTheme.rowTitleFont)
                Text(couldNotStart
                    ? "Tooki needs the Accessibility permission to watch the keyboard."
                    : "Press a shortcut in any app to find out what takes it.")
                    .font(SettingsTheme.rowDescriptionFont)
                    .foregroundStyle(couldNotStart ? AnyShapeStyle(.orange) : AnyShapeStyle(SettingsTheme.secondaryText))
            }
            Spacer()
            if detective.isListening {
                Button("Stop", action: detective.stop)
            } else {
                Button("Start Listening", action: start)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var stage: some View {
        Group {
            if let latest = detective.checks.first {
                DetectiveResultView(check: latest)
                    .id(latest.id)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 34))
                        .foregroundStyle(.indigo)
                        .symbolEffect(.pulse)
                    Text("Listening…")
                        .font(SettingsTheme.rowTitleFont.weight(.medium))
                    Text("Switch to any app and press a shortcut.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding(.vertical, 8)
        .animation(.snappy, value: detective.checks.first?.id)
    }

    private func start() {
        couldNotStart = !detective.start(catalog: .load(tookiShortcuts: tookiShortcuts))
    }
}

/// Two side-by-side choices for how presses are tested, each with its trade-off spelled out.
private struct DetectiveModePicker: View {
    @Binding var mode: ShortcutDetective.TestMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When you press a shortcut")
            HStack(spacing: 10) {
                ForEach(ShortcutDetective.TestMode.allCases, id: \.self) { option in
                    DetectiveModeCard(option: option, isSelected: mode == option) { mode = option }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DetectiveModeCard: View {
    let option: ShortcutDetective.TestMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 4) {
                    Label(title, systemImage: symbol)
                        .font(SettingsTheme.rowTitleFont.weight(.medium))
                    Text(pro).foregroundStyle(.secondary)
                    Text(con).foregroundStyle(.secondary)
                }
                .font(SettingsTheme.controlFont)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(.quaternary.opacity(isSelected ? 0.8 : 0.3), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 1.5 : 0.5)
            }
        }
        .buttonStyle(InteractionButtonStyle(radius: 8))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var title: String {
        option == .runShortcut ? "Run Shortcut" : "Don't Run"
    }

    private var symbol: String {
        option == .runShortcut ? "play.circle" : "hand.raised"
    }

    private var pro: String {
        option == .runShortcut ? "✓ Finds any app that takes it" : "✓ Nothing happens, you stay on this page"
    }

    private var con: String {
        option == .runShortcut ? "✗ The shortcut runs, so it may switch apps" : "✗ Only names shortcuts Tooki knows"
    }
}
