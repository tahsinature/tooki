import SwiftUI
import TookiKit

struct ShelfConversionSettingsView: View {
    @Bindable var model: ShelfImageConversionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(PanelTheme.selectionIndicator)
                    .font(.title3)
                    .frame(width: 32, height: 34)
                    .background(PanelTheme.selectedBackground, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name).font(.system(size: 12, weight: .medium))
                        .lineLimit(2).truncationMode(.middle)
                    Text(model.inputSize).font(.caption2).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 5) {
                field("Format") {
                    ShelfConversionMenu(title: "Format", selection: $model.options.format,
                                        choices: ImageConverter.availableFormats, label: { $0.rawValue })
                }
                Divider()
                field("Image size") {
                    ShelfConversionMenu(title: "Image size", selection: $model.options.size,
                                        choices: ImageConversionOptions.Size.allCases, label: { $0.label })
                }
            }
            .padding(9)
            .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PanelTheme.popupDivider))
            Toggle("Preserve metadata", isOn: $model.options.preserveMetadata)
                .toggleStyle(.checkbox)
                .help("Keep supported camera details and GPS location.")
            Text("Convert first, then preview and choose how to save.")
                .font(.caption2).foregroundStyle(.secondary)
            if !model.errors.isEmpty { ConversionErrorList(messages: model.errors) }
            HStack {
                Text("Esc to go back").font(.caption2).foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                Button("Convert", action: model.convert)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .font(.system(size: 11))
        .controlSize(.small)
        .padding(12)
        .padding(.top, -6)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            content()
        }
    }
}
