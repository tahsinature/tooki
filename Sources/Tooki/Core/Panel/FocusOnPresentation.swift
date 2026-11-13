import SwiftUI

extension View {
    /// Focus an inserted popup's field after SwiftUI has mounted it, rather than during onAppear.
    @MainActor
    func focusOnPresentation(_ focus: FocusState<Bool>.Binding) -> some View {
        focused(focus)
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                focus.wrappedValue = true
            }
    }
}
