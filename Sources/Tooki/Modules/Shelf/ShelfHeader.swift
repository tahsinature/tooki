import AppKit
import SwiftUI

/// The shelf's top bar, the same in every view: the name (drag it to move the shelf),
/// Stack or List, the ⋯ menu, and Hide. Holding ⌥ turns Hide into Delete.
/// An empty shelf leaves out what needs items: the view switch and the item commands.
struct ShelfHeader: View {
    let shelf: Shelf
    let onHide: () -> Void
    let onDelete: () -> Void
    let onClear: () -> Void

    static let height: CGFloat = 42

    @State private var isRenaming = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 0) {
                ShelfTitle(shelf: shelf, isEditing: $isRenaming)
                Spacer(minLength: 4)
            }
            .padding(.leading, 12)
            .frame(maxHeight: .infinity)
            .shelfWindowDragArea()
            if !shelf.isEmpty { ShelfViewSwitch(shelf: shelf) }
            ShelfMoreMenu(shelf: shelf, onRename: { isRenaming = true }, onClear: onClear, onDelete: onDelete)
            ShelfHideButton(shelf: shelf, onHide: onHide, onDelete: onDelete)
        }
        .padding(.trailing, 12)
        .frame(height: Self.height)
    }
}

/// Two icons that show, and switch, how the shelf is shown: a stack or a list.
private struct ShelfViewSwitch: View {
    let shelf: Shelf

    var body: some View {
        HStack(spacing: 2) {
            option(symbol: "square.stack", help: "Show as a stack", isList: false)
            option(symbol: "list.bullet", help: "Show as a list", isList: true)
        }
        .padding(2)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    private func option(symbol: String, help: String, isList: Bool) -> some View {
        let isOn = shelf.isExpanded == isList
        return Button { shelf.isExpanded = isList } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isOn ? .primary : .secondary)
                .frame(width: 24, height: 18)
                .background(isOn ? Color.primary.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Everything you can do with the whole shelf.
private struct ShelfMoreMenu: View {
    let shelf: Shelf
    let onRename: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button("Rename", action: onRename)
            if !shelf.isEmpty {
                Button("Show All in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(shelf.readyURLs)
                }
                Button("Copy All Paths") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shelf.readyURLs.map(\.path).joined(separator: "\n"), forType: .string)
                }
            }
            Divider()
            if !shelf.isEmpty { Button("Clear", action: onClear) }
            Button("Delete Shelf", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Shelf actions")
    }
}

/// Hides the shelf and keeps its items. While ⌥ is held it turns red and deletes the shelf instead.
/// When deleting would throw away copies, it widens to "Delete?" and waits for a second click.
private struct ShelfHideButton: View {
    let shelf: Shelf
    let onHide: () -> Void
    let onDelete: () -> Void

    @State private var optionKey = ShelfOptionKey()

    var body: some View {
        let isArmed = shelf.armed == .delete
        let deletes = optionKey.isDown || isArmed
        Button(action: deletes ? onDelete : onHide) {
            HStack(spacing: 4) {
                Image(systemName: deletes ? "trash" : "minus")
                    .contentTransition(.symbolEffect(.replace))
                if isArmed { Text("Delete?").fixedSize() }
            }
            .font(.system(size: isArmed ? 10 : 9, weight: .bold))
            .foregroundStyle(deletes ? Color.white : Color.primary)
            .padding(.horizontal, isArmed ? 8 : 0)
            .frame(minWidth: 22, minHeight: 22)
            .background(deletes ? Color.red : Color.primary.opacity(0.1), in: Capsule())
            .scaleEffect(deletes && !isArmed ? 1.12 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help(deletes: deletes, isArmed: isArmed))
        .onHover { inside in if !inside, isArmed { shelf.disarm() } }
        .animation(.spring(duration: 0.3, bounce: 0.45), value: deletes)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: isArmed)
        .onAppear { optionKey.start() }
        .onDisappear { optionKey.stop() }
    }

    private func help(deletes: Bool, isArmed: Bool) -> String {
        if isArmed { return "Click again to delete the shelf. Originals stay where they are." }
        return deletes ? "Delete the shelf" : "Hide the shelf. Its items are kept. Hold ⌥ to delete it instead."
    }
}

/// Whether ⌥ is held, in any app: the shelf rarely has focus while you look at it.
@MainActor
@Observable
final class ShelfOptionKey {
    private(set) var isDown = false
    @ObservationIgnored private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }
        isDown = NSEvent.modifierFlags.contains(.option)
        // Both monitors run on the main thread.
        let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.update(event) }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.update(event) }
        }
        monitors = [local, global].compactMap { $0 }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        isDown = false
    }

    private func update(_ event: NSEvent) {
        isDown = event.modifierFlags.contains(.option)
    }
}

extension View {
    /// Empty space that moves the shelf when dragged, with an open hand to say so.
    func shelfWindowDragArea() -> some View {
        modifier(ShelfWindowDragArea())
    }
}

private struct ShelfWindowDragArea: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(WindowDragView())
            .onHover { hovering in
                guard hovering != isHovered else { return }
                isHovered = hovering
                hovering ? NSCursor.openHand.push() : NSCursor.pop()
            }
            .onDisappear {
                if isHovered { NSCursor.pop() }
                isHovered = false
            }
    }

    private struct WindowDragView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { DragView() }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.pop()
        }
    }
}
