import SwiftUI

/// A page inside the shelf, sharing its header and sliding container with item details.
struct ShelfImageConversionView: View {
    let model: ShelfImageConversionModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: model.back) {
                    Label(model.phase == .review ? "Settings" : "All items", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(model.phase == .saving)
                Spacer(minLength: 4)
                Text(model.phase == .review ? "Review results" : model.title)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .frame(height: 32)
            switch model.phase {
            case .settings:
                ShelfConversionSettingsView(model: model)
            case .converting:
                ConversionProgressView(title: "Preparing your preview", detail: "The original files stay unchanged.",
                                       completed: model.completed, total: model.items.count, onCancel: model.discard)
            case .saving:
                ConversionProgressView(title: "Saving results", detail: "Updating this shelf…",
                                       completed: model.completed, total: model.results.count)
            case .review:
                ShelfConversionReviewView(model: model)
            }
        }
        .frame(width: ShelfMotion.width)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshPreviews() }
        }
        .task(id: model.phase) {
            guard model.phase == .review else { return }
            while !Task.isCancelled {
                if NSApp.isActive { await model.refreshPreviews() }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}
