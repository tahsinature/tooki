import AppKit
import SwiftUI

/// Watches clicks only while a number field is focused, without consuming the event.
struct SettingsNumberFocusArea: NSViewRepresentable {
    let isFocused: Bool
    let onOutsideClick: () -> Void

    func makeNSView(context: Context) -> NSView { NSView() }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.view = view
        context.coordinator.onOutsideClick = onOutsideClick
        context.coordinator.setWatching(isFocused)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.setWatching(false)
    }

    @MainActor
    final class Coordinator {
        weak var view: NSView?
        var onOutsideClick: () -> Void = {}
        private var monitor: Any?

        func setWatching(_ watching: Bool) {
            if !watching {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                    MainActor.assumeIsolated {
                        self?.handle(event)
                    }
                    return event
                }
            }
        }

        private func handle(_ event: NSEvent) {
            guard let view, let window = view.window, event.window === window else { return }
            let point = view.convert(event.locationInWindow, from: nil)
            let visibleBounds = view.bounds.intersection(view.visibleRect)
            if !visibleBounds.contains(point) {
                window.makeFirstResponder(nil)
                onOutsideClick()
            }
        }
    }
}
