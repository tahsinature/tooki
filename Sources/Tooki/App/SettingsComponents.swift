import SwiftUI

/// A row holding custom content. SettingsGroupCard supplies its padding and separator.
struct SettingsCardRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A title and grey description on the left, a control on the right.
struct SettingsRow<Control: View>: View {
    let title: String
    var description: String?
    @ViewBuilder let control: Control

    init(_ title: String, description: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            SettingsRowLabel(title: title, description: description)
            control.font(SettingsTheme.controlFont)
        }
    }
}

struct SettingsRowLabel: View {
    let title: String
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SettingsTheme.rowTitleFont)
                .foregroundStyle(SettingsTheme.primaryText)
            if let description {
                Text(description)
                    .font(SettingsTheme.rowDescriptionFont)
                    .foregroundStyle(SettingsTheme.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The most common row: a title, a description and a switch.
struct SettingsToggleRow: View {
    let title: String
    var description: String?
    @Binding var isOn: Bool

    init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 16) {
            // A native switch doesn't toggle when its separate label is clicked.
            Button { isOn.toggle() } label: {
                SettingsRowLabel(title: title, description: description)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityHidden(true)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityHint(description ?? "")
        }
    }
}
