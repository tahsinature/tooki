import AppKit
import SwiftUI
import TookiKit

/// Shows a shortcut as key caps, or "Add Hotkey". Clicking it opens a recorder popover.
struct HotkeyRecorder: View {
    let combo: KeyCombo?
    /// Returns a message when the combo can't be used.
    let validate: (KeyCombo) -> String?
    let onRecordingChange: (Bool) -> Void
    let onChange: (KeyCombo?) -> Void

    @ViewState private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            if let combo {
                KeyCaps(symbols: combo.symbols)
            } else {
                Text("Add Hotkey").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            if combo != nil {
                Button("Remove Hotkey") { onChange(nil) }
            }
        }
        .popover(isPresented: $isRecording, arrowEdge: .bottom) {
            RecorderPanel(current: combo, validate: validate, onRecordingChange: onRecordingChange) { recorded in
                isRecording = false
                if let recorded { onChange(recorded.combo) }
            }
        }
    }
}

/// What the user did in the recorder. `nil` from the panel means cancelled.
private struct RecordedHotkey {
    /// `nil` when the user cleared the hotkey.
    let combo: KeyCombo?
}

private struct RecorderPanel: View {
    let current: KeyCombo?
    let validate: (KeyCombo) -> String?
    let onRecordingChange: (Bool) -> Void
    let onFinish: (RecordedHotkey?) -> Void

    @ViewState private var heldModifiers: KeyCombo.Modifiers = []
    @ViewState private var problem: String?
    @ViewState private var monitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            preview
                .frame(width: 300, height: 110)
            Divider()
            Text(problem ?? "Press Esc to cancel, Delete to remove")
                .font(.caption)
                .foregroundStyle(problem == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                .padding(10)
        }
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    @ViewBuilder
    private var preview: some View {
        if !heldModifiers.isEmpty {
            KeyCaps(symbols: heldModifiers.symbols, size: .large)
        } else if let current {
            KeyCaps(symbols: current.symbols, size: .large).opacity(0.4)
        } else {
            VStack(spacing: 4) {
                Text("Record a shortcut").font(.headline)
                Text("Hold Caps Lock to use the Hyper key").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func startListening() {
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let shouldSwallow = MainActor.assumeIsolated { handle(event) }
            return shouldSwallow ? nil : event
        }
    }

    private func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onRecordingChange(false)
    }

    /// Returns `true` to keep the key press away from the rest of the window.
    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = KeyCombo.Modifiers(event.modifierFlags)
        if event.type == .flagsChanged {
            heldModifiers = modifiers
            return false
        }
        if modifiers.isEmpty, event.keyCode == KeyCode.escape {
            onFinish(nil)
        } else if modifiers.isEmpty, event.keyCode == KeyCode.delete {
            onFinish(RecordedHotkey(combo: nil))
        } else if let combo = KeyCombo(keyCode: event.keyCode, modifiers: modifiers) {
            if let message = validate(combo) {
                problem = message
            } else {
                onFinish(RecordedHotkey(combo: combo))
            }
        } else {
            problem = KeyCode.name(for: event.keyCode) == nil
                ? "That key isn't supported"
                : "Add a modifier like ⌘ or the Hyper key"
        }
        return true
    }
}
