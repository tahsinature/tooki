import AppKit
import TookiKit

enum EmojiAction: String, CaseIterable, PanelActionItem {
    case copy
    case paste
    case copyShortcode

    var id: String { rawValue }
    var isDestructive: Bool { false }

    var title: String {
        switch self {
        case .paste: "Paste Emoji"
        case .copy: "Copy Emoji"
        case .copyShortcode: "Copy Shortcode"
        }
    }

    var icon: PanelIcon {
        switch self {
        case .paste: .symbol("doc.on.clipboard")
        case .copy: .symbol("doc.on.doc")
        case .copyShortcode: .symbol("textformat")
        }
    }

    var shortcut: String {
        switch self {
        case .copy: "↵"
        case .paste: "⌘↵"
        case .copyShortcode: ""
        }
    }
}

/// Shows the emoji picker and copies the chosen emoji, or pastes it into the app you were using.
@MainActor
final class EmojiPanelController {
    private var panel: FloatingPanel?
    /// Runs after Esc closes the panel, e.g. to go back to root search. Set before each `show()`.
    var onBack: (() -> Void)?
    private var recent = RecentEmojiFile.load()

    var isShowing: Bool { panel?.isVisible == true }

    func toggle() {
        isShowing ? close() : show()
    }

    func show() {
        panel?.close()
        let model = EmojiPanelModel(recentCharacters: recent)
        let panel = FloatingPanel(size: EmojiPanelView.size) {
            EmojiPanelView(
                model: model,
                onRun: { [weak self, weak model] action in
                    guard let emoji = model?.selected else { return }
                    self?.perform(action, on: emoji)
                },
                onCancel: { [weak self] in self?.dismiss() }
            )
        }
        panel.onEscape = { [weak self, weak model] in
            if model?.isShowingActions == true { model?.isShowingActions = false } else { self?.dismiss() }
        }
        self.panel = panel
        panel.present()
    }

    func close() {
        panel?.close()
        panel = nil
    }

    /// Esc with nothing left to back out of.
    private func dismiss() {
        close()
        onBack?()
    }

    private func perform(_ action: EmojiAction, on emoji: Emoji) {
        close()
        remember(emoji)
        switch action {
        case .paste:
            Task {
                // Let focus return to the previous app before typing into it.
                try? await Task.sleep(for: .milliseconds(80))
                Paster.paste(emoji.character)
            }
        case .copy: Paster.copy(emoji.character)
        case .copyShortcode: Paster.copy(":\(emoji.shortcode):")
        }
    }

    private func remember(_ emoji: Emoji) {
        recent.removeAll { $0 == emoji.character }
        recent.insert(emoji.character, at: 0)
        recent = Array(recent.prefix(Self.recentLimit))
        RecentEmojiFile.save(recent)
    }

    private static let recentLimit = 20
}

/// The emoji you picked last, newest first. Private to this Mac.
private enum RecentEmojiFile {
    static let url = StoragePaths.dataDirectory.appending(path: "recent-emoji.json")

    static func load() -> [String] {
        JSONFile.read(url).flatMap { try? JSONFile.decoder.decode([String].self, from: $0) } ?? []
    }

    static func save(_ characters: [String]) {
        guard let data = try? JSONFile.encoder.encode(characters) else { return }
        try? JSONFile.write(data, to: url)
    }
}
