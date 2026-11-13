import SwiftUI

extension View {
    /// Focus when the field's window is ready, including when a retained panel reopens.
    /// Pause this for the main search while a popup owns keyboard input.
    @MainActor
    func focusOnPresentation(_ focus: FocusState<Bool>.Binding, when isEnabled: Bool = true) -> some View {
        focused(focus)
            .background {
                PresentationFocusObserver(isEnabled: isEnabled) { focus.wrappedValue = $0 }
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
