import AppKit
import SwiftUI
import TookiKit

/// How a shortcut's action is shown: a name and an icon.
struct ShortcutActionInfo {
    enum Icon {
        case symbol(String, Color)
        case app(NSImage)
    }

    let title: String
    let icon: Icon

    init(action: String) {
        if action.hasPrefix("open:") {
            let target = String(action.dropFirst("open:".count))
            let url = AppLauncher.url(for: target)
            title = url?.deletingPathExtension().lastPathComponent ?? target
            icon = url.map { .app(NSWorkspace.shared.icon(forFile: $0.path)) } ?? .symbol("questionmark.app", .gray)
            return
        }
        (title, icon) = switch action {
        case "search": ("Search", .symbol("magnifyingglass", .blue))
        case "clipboard": ("Clipboard History", .symbol("list.clipboard.fill", .orange))
        case "menuBar.search": ("Search Menu Bar", .symbol("menubar.rectangle", .teal))
        case "menuBar.toggle": ("Show Hidden Menu Bar Icons", .symbol("menubar.arrow.up.rectangle", .teal))
        case "keepAwake.toggle": ("Toggle Keep Awake", .symbol("cup.and.saucer.fill", .brown))
        case "settings": ("Open Tooki Settings", .symbol("gearshape.fill", .gray))
        default: (action, .symbol("questionmark", .gray))
        }
    }
}

struct ShortcutActionIcon: View {
    let icon: ShortcutActionInfo.Icon

    var body: some View {
        switch icon {
        case .symbol(let name, let color):
            IconTile(symbol: name, color: color, size: 24)
        case .app(let image):
            Image(nsImage: image)
                .resizable()
                .frame(width: 24, height: 24)
        }
    }
}
