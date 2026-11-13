import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, hyperKey, snippets, clipboard, shelf, menuBar, keepAwake, shortcuts, about

    enum Group: String, CaseIterable {
        case app = "App", tools = "Tools", info = ""
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .hyperKey: "Hyper Key"
        case .snippets: "Snippets"
        case .clipboard: "Clipboard"
        case .shelf: "Shelf"
        case .menuBar: "Menu Bar"
        case .keepAwake: "Keep Awake"
        case .shortcuts: "Shortcuts"
        case .general: "General"
        case .about: "About"
        }
    }

    var group: Group {
        switch self {
        case .general, .hyperKey, .shortcuts: .app
        case .snippets, .clipboard, .shelf, .menuBar, .keepAwake: .tools
        case .about: .info
        }
    }

    var icon: String {
        switch self {
        case .hyperKey: "bolt.fill"
        case .snippets: "text.cursor"
        case .clipboard: "list.clipboard.fill"
        case .shelf: "tray.full.fill"
        case .menuBar: "menubar.rectangle"
        case .keepAwake: "cup.and.saucer.fill"
        case .shortcuts: "command"
        case .general: "gearshape.fill"
        case .about: "info.circle.fill"
        }
    }

    var tileColor: Color {
        switch self {
        case .general, .about: .gray
        case .hyperKey: .orange
        case .snippets: .purple
        case .clipboard: .blue
        case .shelf: .teal
        case .menuBar: .indigo
        case .keepAwake: .brown
        case .shortcuts: .pink
        }
    }

    /// Search includes the controls a page contains, so "coffee" and "login" are useful
    /// without requiring the user to know the corresponding page's name.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        let searchable = "\(title) \(searchTerms)"
        return words.allSatisfy { searchable.localizedStandardContains(String($0)) }
    }

    private var searchTerms: String {
        switch self {
        case .general: "permissions accessibility startup login launch configuration config reload folder url scheme panel navigation resume restore last search root shortcut"
        case .hyperKey: "caps lock keyboard modifier remap escape hyper"
        case .snippets: "text expansion keyword placeholders templates variables paste"
        case .clipboard: "history retention images text links ignored apps passwords sensitive copy paste"
        case .shelf: "shelves files folders copies originals drag drop image conversion convert preview png jpeg heif"
        case .menuBar: "menubar status icons hidden shown organizer layout appearance tint thaw bar reveal notch"
        case .keepAwake: "coffee caffeine sleep display power battery plugged duration timer apps menu bar icon"
        case .shortcuts: "hotkeys keyboard bindings apps detective record conflict"
        case .about: "tooki version updates release credits license source github"
        }
    }
}
