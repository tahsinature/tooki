import SwiftUI
import TookiKit

/// A placeholder snippets can use, described for people choosing one.
struct SnippetPlaceholder: Identifiable {
    let token: String
    let title: String
    let detail: String
    let systemImage: String

    var id: String { token }

    static let all = [
        SnippetPlaceholder(token: "{date}", title: "Date", detail: "Today's date", systemImage: "calendar"),
        SnippetPlaceholder(token: "{date:EEEE, MMM d}", title: "Date, Custom Format", detail: "Edit the format after inserting", systemImage: "calendar.badge.clock"),
        SnippetPlaceholder(token: "{time}", title: "Time", detail: "The current time", systemImage: "clock"),
        SnippetPlaceholder(token: "{datetime}", title: "Date and Time", detail: "Your local date and time", systemImage: "calendar.badge.clock"),
        SnippetPlaceholder(token: "{uuid}", title: "UUID", detail: "A new unique identifier each time", systemImage: "number"),
        SnippetPlaceholder(token: "{uuid:lowercase}", title: "UUID, Lowercase", detail: "A unique identifier in lowercase", systemImage: "number"),
        SnippetPlaceholder(token: "{clipboard}", title: "Clipboard Text", detail: "What you last copied", systemImage: "doc.on.clipboard"),
        SnippetPlaceholder(token: "{cursor}", title: "Cursor Position", detail: "Where the cursor lands after expanding", systemImage: "character.cursor.ibeam"),
        SnippetPlaceholder(token: "{argument:name}", title: "Argument", detail: "Asks for a value when expanding. Rename \"name\".", systemImage: "questionmark.bubble"),
    ]

    /// A live example, e.g. "Wednesday, Nov 4", for placeholders that have one.
    var example: String? {
        guard token.hasPrefix("{date") || token.hasPrefix("{time") else { return nil }
        return PlaceholderExpander.expand(token, context: ExpansionContext()).text
    }
}

/// "Insert Placeholder" menu listing each placeholder with what it does and its token.
struct PlaceholderMenu: View {
    let insert: (String) -> Void

    var body: some View {
        Menu {
            ForEach(SnippetPlaceholder.all) { placeholder in
                Button { insert(placeholder.token) } label: {
                    Label(placeholder.title, systemImage: placeholder.systemImage)
                    Text(subtitle(for: placeholder))
                }
            }
        } label: {
            Label("Insert Placeholder", systemImage: "curlybraces")
        }
        .fixedSize()
    }

    private func subtitle(for placeholder: SnippetPlaceholder) -> String {
        let parts = [placeholder.detail, placeholder.example.map { "e.g. \($0)" }, placeholder.token]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }
}
