import AppKit

/// Retains the hosting view as well as its model, preserving scroll position and drafts.
@MainActor
protocol ResumablePanelController: AnyObject {
    var panel: FloatingPanel? { get set }
    var remembersPosition: () -> Bool { get set }
}

extension ResumablePanelController {
    /// Read the preference on every presentation without recreating the retained view or its drafts.
    func configurePositionRestoration(for panel: FloatingPanel, reset: @escaping () -> Void) {
        let remembersPosition = remembersPosition
        panel.preparePositionForPresentation = {
            if !remembersPosition() { reset() }
        }
    }

    var isShowing: Bool { panel?.isVisible == true }

    func close() {
        panel?.close()
    }

    @discardableResult
    func resume() -> Bool {
        guard let panel else { return false }
        QuickLookPreview.closeCurrent()
        panel.present(restoring: true)
        return true
    }
}
