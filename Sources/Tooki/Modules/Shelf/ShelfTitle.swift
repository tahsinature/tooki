import SwiftUI

/// The shelf's name. Rename it from the ⋯ menu: Return saves and Esc cancels.
/// Otherwise it lets clicks through, so dragging it moves the shelf.
/// Names are kept short enough to fit; typing past the limit shakes the field.
struct ShelfTitle: View {
    static let maxLength = 20

    let shelf: Shelf
    @Binding var isEditing: Bool
    var font: Font = .headline

    @State private var draft = ""
    @State private var rejectedTyping = 0
    @State private var isOverLimit = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField("Name", text: $draft)
                .textFieldStyle(.plain)
                .font(font)
                .focused($isFocused)
                .foregroundStyle(isOverLimit ? Color.red : Color.primary)
                .modifier(ShelfShake(shakes: CGFloat(rejectedTyping)))
                .onChange(of: draft) { _, text in limit(text) }
                .onAppear {
                    draft = shelf.name
                    isFocused = true
                }
                .onSubmit(save)
                .onExitCommand { isEditing = false }
                .onChange(of: isFocused) { _, focused in if !focused { save() } }
        } else {
            Text(shelf.name)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .allowsHitTesting(false)
        }
    }

    private func limit(_ text: String) {
        guard text.count > Self.maxLength else { return }
        draft = String(text.prefix(Self.maxLength))
        withAnimation(.linear(duration: 0.3)) { rejectedTyping += 1 }
        isOverLimit = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.2)) { isOverLimit = false }
        }
    }

    private func save() {
        guard isEditing else { return }
        shelf.rename(to: draft)
        isEditing = false
    }
}

/// Moves its view side to side a few times for each whole step of `shakes`, like a refused password.
struct ShelfShake: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(shakes * .pi * 6), y: 0))
    }
}
