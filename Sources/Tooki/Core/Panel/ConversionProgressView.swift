import SwiftUI

/// Shared loading surface for converters. Progress counts completed items, not guessed time.
struct ConversionProgressView: View {
    let title: String
    let detail: String
    let completed: Int
    let total: Int
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.regular)
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
            if total > 1 {
                ProgressView(value: Double(completed), total: Double(total))
                Text("\(completed) of \(total) completed").font(.caption).foregroundStyle(.secondary)
            }
            if let onCancel { Button("Cancel", action: onCancel).buttonStyle(.plain).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
