import AppKit

/// Retains the hosting view as well as its model, preserving scroll position and drafts.
@MainActor
protocol ResumablePanelController: AnyObject {
    var panel: FloatingPanel? { get set }
}

extension ResumablePanelController {
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
