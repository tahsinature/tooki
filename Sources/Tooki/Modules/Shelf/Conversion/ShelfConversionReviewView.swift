import SwiftUI

struct ShelfConversionReviewView: View {
    let model: ShelfImageConversionModel
    var showsActions = true
    @ViewState private var showsOriginal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let result = model.current {
                if model.results.count > 1 { navigation }
                HStack(spacing: 8) {
                    Button("Quick Look", systemImage: "eye", action: model.quickLook)
                        .buttonStyle(.borderless)
                    Spacer(minLength: 0)
                    ShelfConversionOpenWith(result: result, model: model)
                }
                .font(.caption)
                .disabled(result.error != nil)
                if let error = result.error {
                    ConversionErrorList(messages: [error])
                } else {
                    ConversionPreviewImage(url: showsOriginal ? result.item.url : result.preview.url, revision: result.revision)
                    HStack {
                        Text(result.preview.url.lastPathComponent)
                            .font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button(showsOriginal ? "Show result" : "Show original") { showsOriginal.toggle() }
                            .buttonStyle(.plain).foregroundStyle(Color.accentColor).font(.caption2)
                    }
                    Text("\(result.preview.sourceByteCount.formatted(.byteCount(style: .file))) → \(result.details.byteCount.formatted(.byteCount(style: .file)))")
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    Text("\(result.preview.format.rawValue) · \(result.details.width) × \(result.details.height) px")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if model.results.count > 1 { Text(model.totalSizeChange).font(.caption2).foregroundStyle(.secondary) }
                if !model.errors.isEmpty { ConversionErrorList(messages: model.errors) }
                Divider()
                Text(model.replaceExplanation).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showsActions {
                    Text(model.results.count > 1 ? "Save actions apply to all \(model.results.count) results." : "Choose how to save this result.")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Button("Discard", action: model.discard).buttonStyle(.plain).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Button(model.saveCopyTitle) { model.save(.copy) }.disabled(!model.canSave)
                    }
                    Button { model.save(.replace) } label: {
                        Text(model.replaceTitle).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSave)
                }
            }
        }
        .controlSize(.small)
        .padding(12)
        .padding(.top, -6)
        .onChange(of: model.current?.id) { _, _ in showsOriginal = false }
    }

    private var navigation: some View {
        HStack {
            Button("Previous result", systemImage: "chevron.left") { model.moveReview(by: -1) }
                .disabled(model.reviewIndex == 0)
            Spacer(minLength: 4)
            Text("\(model.reviewIndex + 1) of \(model.results.count)").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Next result", systemImage: "chevron.right") { model.moveReview(by: 1) }
                .disabled(model.reviewIndex + 1 >= model.results.count)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
    }
}
