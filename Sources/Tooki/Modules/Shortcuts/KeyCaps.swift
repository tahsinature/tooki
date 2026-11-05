import SwiftUI

/// A single keyboard key, drawn like a physical key cap.
struct KeyCap: View {
    enum Size {
        case regular, large

        var height: CGFloat { self == .large ? 34 : 22 }
        var font: Font { .system(size: self == .large ? 15 : 11, weight: .medium, design: .rounded) }
        var cornerRadius: CGFloat { self == .large ? 7 : 5 }
    }

    let symbol: String
    var size = Size.regular

    var body: some View {
        Text(symbol)
            .font(size.font)
            .padding(.horizontal, symbol.count > 1 ? 8 : 0)
            .frame(minWidth: size.height, minHeight: size.height)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: size.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: size.cornerRadius).strokeBorder(.separator, lineWidth: 0.5)
            }
    }
}

struct KeyCaps: View {
    let symbols: [String]
    var size = KeyCap.Size.regular

    var body: some View {
        HStack(spacing: size == .large ? 6 : 3) {
            ForEach(symbols.indices, id: \.self) { index in
                KeyCap(symbol: symbols[index], size: size)
            }
        }
    }
}
