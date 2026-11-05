import SwiftUI

/// A small keyboard with Caps Lock and the four modifiers it stands for highlighted.
struct HyperKeyboardIllustration: View {
    let isEnabled: Bool

    private enum Role { case plain, hyper, modifier }

    private struct Key {
        let label: String
        var width: CGFloat = 1
        var role = Role.plain
    }

    // Every row adds up to 14.5 key widths so the right edges line up.
    private static let rows: [[Key]] = [
        "`1234567890-=".map { Key(label: String($0)) } + [Key(label: "delete", width: 1.5)],
        [Key(label: "tab", width: 1.5)] + "QWERTYUIOP[]\\".map { Key(label: String($0)) },
        [Key(label: "⇪ caps lock", width: 1.8, role: .hyper)] + "ASDFGHJKL;'".map { Key(label: String($0)) }
            + [Key(label: "return", width: 1.7)],
        [Key(label: "⇧", width: 2.3, role: .modifier)] + "ZXCVBNM,./".map { Key(label: String($0)) }
            + [Key(label: "⇧", width: 2.2, role: .modifier)],
        [
            Key(label: "fn"), Key(label: "⌃", width: 1.2, role: .modifier), Key(label: "⌥", width: 1.2, role: .modifier),
            Key(label: "⌘", width: 1.5, role: .modifier), Key(label: "", width: 5.6),
            Key(label: "⌘", width: 1.5, role: .modifier), Key(label: "⌥", width: 1.2), Key(label: "◀ ▶", width: 1.3),
        ],
    ]

    private let unit: CGFloat = 26
    private let gap: CGFloat = 4

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: gap) {
                ForEach(Self.rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(Self.rows[row].indices, id: \.self) { index in
                            keyCap(Self.rows[row][index])
                        }
                    }
                }
            }
            .padding(10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                KeyCap(symbol: "⇪ caps lock", size: .large)
                Text("=").font(.title2).foregroundStyle(.secondary)
                KeyCaps(symbols: ["⌃", "⌥", "⇧", "⌘"], size: .large)
            }
            .opacity(isEnabled ? 1 : 0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.25), value: isEnabled)
    }

    private func keyCap(_ key: Key) -> some View {
        let highlighted = isEnabled && key.role != .plain
        return Text(key.label)
            .font(.system(size: key.label.count > 1 ? 8 : 10, weight: .medium, design: .rounded))
            .foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(width: key.width * (unit + gap) - gap, height: unit)
            .background(background(for: key.role), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: highlighted && key.role == .hyper ? .purple.opacity(0.6) : .clear, radius: 6)
    }

    private func background(for role: Role) -> AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(.quaternary) }
        return switch role {
        case .plain: AnyShapeStyle(.quaternary)
        case .hyper: AnyShapeStyle(Color.purple.gradient)
        case .modifier: AnyShapeStyle(Color.purple.opacity(0.45))
        }
    }
}
