import AppKit
import SwiftUI
import Testing
import TookiKit
@testable import Tooki

extension PanelRestorationTests {
    @Test func clipboardStoreDrivesTheRetainedNativePanel() async throws {
        _ = NSApplication.shared
        let items = (0..<80).map { ClipboardItem(text: "Entry \($0)") }
        let model = ClipboardPanelModel(history: ClipboardHistory(initialItems: items), targetAppName: "Example")
        let hosting = NSHostingView(rootView: ClipboardPanelView(model: model, onAction: { _ in }, onCancel: {}, onClose: {}))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 750, height: 480),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(150))

        model.moveSelection(by: .max)
        #expect(model.selectedItem?.id == items.last?.id)
        model.query = "Entry"
        #expect(model.selectedItem?.id == items.first?.id)
        model.selectedID = items[40].id
        model.query = "Entry" // Native fields can recommit unchanged text on focus changes.
        #expect(model.selectedItem?.id == items[40].id)
        model.resetPosition()
        #expect(model.selectedItem?.id == items.first?.id)
        #expect(model.query == "Entry")
        model.typeFilter = .image
        #expect(model.selectedItem == nil)
        model.typeFilter = nil
        #expect(model.orderedResults.count == items.count)
        #expect(hosting.rootView.model === model)
    }
}
