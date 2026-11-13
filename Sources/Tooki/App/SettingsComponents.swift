import SwiftUI

/// Scrollable grouped cards, sharing the settings window's continuous content surface.
struct SettingsScrollPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) { content }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 26)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(SettingsTheme.contentBackground)
        .font(SettingsTheme.rowTitleFont)
        .buttonStyle(InteractionButtonStyle(
            restingFill: Color.primary.opacity(0.065),
            horizontalPadding: 11, verticalPadding: 6
        ))
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
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SettingsTheme.primaryText)
                    .padding(.horizontal, 12)
            }
            SettingsGroupCard { content }
            footer
                .font(SettingsTheme.rowDescriptionFont)
                .foregroundStyle(SettingsTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
        }
    }
}

extension SettingsSection where Footer == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}

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
        HStack(spacing: 20) {
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
        .padding(.vertical, 1)
        .modifier(InteractionHover())
    }
}
