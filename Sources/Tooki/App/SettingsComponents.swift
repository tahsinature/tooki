import SwiftUI

/// A page of settings sections, drawn as a grouped form like System Settings.
struct SettingsScrollPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}

/// A titled group of rows with an optional footnote.
struct SettingsSection<Content: View, Footer: View>: View {
    let title: String?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(_ title: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        Section {
            content
        } header: {
            if let title { Text(title) }
        } footer: {
            footer
                .font(SettingsTheme.rowDescriptionFont)
                .foregroundStyle(SettingsTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SettingsSection where Footer == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}

/// A form row holding custom content. The form draws the padding and the separators.
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
        HStack(spacing: 20) {
            SettingsRowLabel(title: title, description: description)
            control
        }
    }
}

struct SettingsRowLabel: View {
    let title: String
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        SettingsRow(title, description: description) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
