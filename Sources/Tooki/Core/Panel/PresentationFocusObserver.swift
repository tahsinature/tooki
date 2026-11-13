import SwiftUI

/// Connects the shared SwiftUI focus behavior to the field's own window.
struct PresentationFocusObserver: NSViewRepresentable {
    let isEnabled: Bool
    let setFocused: (Bool) -> Void

    func makeNSView(context: Context) -> PresentationFocusView {
        let view = PresentationFocusView()
        view.update(isEnabled: isEnabled, setFocused: setFocused)
        return view
    }

    func updateNSView(_ view: PresentationFocusView, context: Context) {
        view.update(isEnabled: isEnabled, setFocused: setFocused)
    }

    static func dismantleNSView(_ view: PresentationFocusView, coordinator: ()) {
        view.stopObserving()
    }
}
