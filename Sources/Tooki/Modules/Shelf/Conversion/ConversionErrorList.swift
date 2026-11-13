import SwiftUI

struct ConversionErrorList: View {
    let messages: [String]

    var body: some View {
        ScrollView {
            Label(messages.joined(separator: "\n\n"), systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: min(CGFloat(messages.count) * 64, 120))
        .padding(8)
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
    }
}
