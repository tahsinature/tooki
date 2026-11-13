import AppKit

/// Observes attachment and key-window changes without replacing SwiftUI's native text field.
final class PresentationFocusView: NSView {
    private var isEnabled = false
    private var setFocused: (Bool) -> Void = { _ in }
    private var focusTask: Task<Void, Never>?

    func update(isEnabled: Bool, setFocused: @escaping (Bool) -> Void) {
        self.setFocused = setFocused
        guard self.isEnabled != isEnabled else { return }
        self.isEnabled = isEnabled
        if isEnabled {
            requestFocus()
        } else {
            focusTask?.cancel()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopObserving()
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowBecameKey),
            name: NSWindow.didBecomeKeyNotification, object: window
        )
        requestFocus()
    }

    func stopObserving() {
        focusTask?.cancel()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    @objc private func windowBecameKey(_ notification: Notification) {
        requestFocus()
    }

    private func requestFocus() {
        focusTask?.cancel()
        guard isEnabled, let window, window.isKeyWindow else { return }
        focusTask = Task { @MainActor [weak self, weak window] in
            // Attachment can happen during SwiftUI's update. Wait until its field is mounted.
            await Task.yield()
            guard let self, let window, canFocus(in: window) else { return }
            // A retained FocusState can still be true after native focus moved to another control.
            setFocused(false)
            await Task.yield()
            guard canFocus(in: window) else { return }
            setFocused(true)
        }
    }

    private func canFocus(in window: NSWindow) -> Bool {
        !Task.isCancelled && isEnabled && self.window === window && window.isKeyWindow
    }
}
