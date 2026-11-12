import SwiftUI
import TookiKit

/// Creates or edits a snippet inside the panel: the text on the left, its name, collection and
/// keyword on the right. ⌘↵ saves, Esc goes back without saving.
struct SnippetFormView: View {
    @Bindable var model: SnippetPanelModel
    let onBack: () -> Void
    let onSave: () -> Void

    @ViewState private var insertion = TextInsertion()
    @FocusState private var isNameFocused: Bool

    var body: some View {
        if let form = model.form {
            VStack(spacing: 0) {
                header(isNew: form.isNew)
                PanelTheme.separator.frame(height: 1)
                HStack(alignment: .top, spacing: 20) {
                    if model.form?.draft.dynamic != nil {
                        DynamicDefinitionEditor(definition: dynamicBinding, snippet: form.draft)
                    } else {
                        textColumn
                    }
                    fieldsColumn
                        .frame(width: 220)
                }
                .padding(16)
                .frame(maxHeight: .infinity)
                BottomActionBar(
                    title: form.isNew ? "Create Snippet" : "Edit Snippet",
                    icon: .symbol("doc.text"),
                    primaryActionTitle: "Save Snippet",
                    primaryShortcut: "⌘↵",
                    onPrimaryAction: onSave,
                    onShowActions: nil
                )
            }
            .frame(width: PanelTheme.listDetailSize.width, height: PanelTheme.listDetailSize.height)
            .panelSurface()
            .background {
                // Invisible, only here for the shortcut.
                Button("Save", action: onSave)
                    .keyboardShortcut(.return, modifiers: .command)
                    .hidden()
            }
            .onAppear { Task { isNameFocused = form.draft.name.isEmpty } }
        }
    }

    private func header(isNew: Bool) -> some View {
        HStack(spacing: PanelTheme.rowSpacing) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(InteractionButtonStyle())
            .foregroundStyle(PanelTheme.secondaryText)
            .help("Back (esc)")
            .accessibilityLabel("Back")
            Text(isNew ? "Create Snippet" : "Edit Snippet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PanelTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: PanelTheme.headerHeight)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Snippet")
            SnippetTextEditor(text: draft.text, insertion: insertion)
                .padding(6)
                .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PanelTheme.border, lineWidth: 0.5))
            HStack {
                Text("Use {placeholders} for the date, clipboard, cursor and more.")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.tertiaryText)
                Spacer()
                PlaceholderMenu(insert: insertion.insert)
                    .controlSize(.small)
            }
        }
    }

    private var fieldsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Snippet type", selection: Binding(get: { model.form?.draft.dynamic != nil }, set: { dynamic in
                if dynamic { model.form?.draft.dynamic = SnippetGalleryExamples.email.dynamic }
                else { model.form?.draft.dynamic = nil }
            })) {
                Text("Text").tag(false)
                Text("Dynamic").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Snippet type")
            field("Name") {
                TextField("Email signature", text: draft.name)
                    .focused($isNameFocused)
            }
            field("Collection") {
                HStack(spacing: 4) {
                    TextField("None", text: draft.collection)
                    if !model.collections.isEmpty {
                        Menu {
                            ForEach(model.collections, id: \.self) { name in
                                Button(name) { model.form?.draft.collection = name }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .menuStyle(.button)
                        .buttonStyle(InteractionButtonStyle())
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .foregroundStyle(PanelTheme.secondaryText)
                        .help("Pick an existing collection")
                    }
                }
            }
            field("Keyword") {
                TextField(";keyword", text: draft.keyword)
                    .font(.system(size: 13, design: .monospaced))
            }
            if model.draftKeywordIsTaken {
                Label("Another snippet uses this keyword.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                Text(model.form?.draft.dynamic == nil ? "Typing the keyword anywhere replaces it with the snippet." : "Type this prefix, your input, then the completion key. No chooser opens while typing.")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = model.draftError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            Spacer()
        }
    }

    private var dynamicBinding: Binding<DynamicSnippet> {
        Binding(get: { model.form?.draft.dynamic ?? DynamicSnippet() }, set: { model.form?.draft.dynamic = $0; model.draftError = nil })
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(PanelTheme.labelFont)
            .foregroundStyle(PanelTheme.secondaryText)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            content()
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(PanelTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(PanelTheme.border, lineWidth: 0.5))
        }
    }

    /// Bindings into the draft. The form only shows while a draft exists.
    private var draft: DraftBindings { DraftBindings(model: model) }
}

@MainActor
private struct DraftBindings {
    let model: SnippetPanelModel

    var name: Binding<String> { binding(\.name) }
    var collection: Binding<String> { binding(\.collection) }
    var keyword: Binding<String> { binding(\.keyword) }
    var text: Binding<String> { binding(\.text) }

    private func binding(_ keyPath: WritableKeyPath<Snippet, String>) -> Binding<String> {
        Binding(
            get: { model.form?.draft[keyPath: keyPath] ?? "" },
            set: { model.form?.draft[keyPath: keyPath] = $0 }
        )
    }
}
