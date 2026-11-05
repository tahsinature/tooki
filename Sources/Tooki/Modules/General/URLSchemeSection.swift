import SwiftUI
import TookiKit

/// Lists every `tooki://` link other apps and scripts can use. Click a row to copy it.
struct URLSchemeSection: View {
    var body: some View {
        Section {
            ForEach(Self.shelfLinks) { URLSchemeRow(link: $0) }
        } header: {
            Text("URL Scheme: Shelf")
        } footer: {
            Text("Click a link to copy it, or ⓘ for what it does and examples. Run links with `open -g \"<link>\"` and quote them in zsh. Unknown links beep.")
                .foregroundStyle(.secondary)
        }

        Section {
            ForEach(HotkeyAction.builtIns, id: \.self) { URLSchemeRow(link: Self.actionLink($0)) }
        } header: {
            Text("URL Scheme: Actions")
        } footer: {
            Text("The same actions you can bind on the Shortcuts page. Opening apps isn't available from links.")
                .foregroundStyle(.secondary)
        }
    }

    private static let shelfLinks = [
        URLSchemeLink(
            title: "Add files or folders",
            copyText: "tooki://shelf/add?path=",
            label: "tooki://shelf/add?path=…",
            details: """
            Adds each path and shows the shelf. Repeat path= for more items, and percent-encode each path \
            (a space becomes %20).

            By default the shelf links to your original, so dragging it out later can move it. \
            Add mode=copy to put Tooki's own copy on the shelf instead; your original never moves.
            """,
            examples: [
                #"open -g "tooki://shelf/add?path=$HOME/Downloads/report.pdf""#,
                #"open -g "tooki://shelf/add?path=$HOME/Desktop/a.png&path=$HOME/Desktop/b.png&mode=copy""#,
            ]
        ),
        simpleLink("show", "Show the shelf", "Brings the shelf back where you left it, without changing what's on it."),
        simpleLink("hide", "Hide the shelf", "Hides the shelf. Its items stay and come back next time it shows."),
        simpleLink("toggle", "Show or hide the shelf", "Shows the shelf when hidden and hides it when shown. Handy for a keyboard tool like Raycast or skhd."),
        simpleLink("clear", "Empty and hide the shelf", "Removes every item and hides the shelf. Originals stay where they are; Tooki's copies are deleted."),
        URLSchemeLink(
            title: "tooki-shelf script",
            copyText: shelfScript,
            label: "tooki-shelf",
            details: """
            A small shell script that builds the add link for you, so you don't have to encode paths. \
            Click to copy it, save it as tooki-shelf somewhere on your PATH, and make it executable \
            with chmod +x. Pass -c to add copies instead of originals.
            """,
            examples: [
                "tooki-shelf ~/Downloads/*.pdf",
                "tooki-shelf -c report.pdf photos/",
                "fd -e png | fzf -m | xargs tooki-shelf",
            ]
        ),
    ]

    private static func simpleLink(_ verb: String, _ title: String, _ details: String) -> URLSchemeLink {
        let link = "tooki://shelf/\(verb)"
        return URLSchemeLink(title: title, copyText: link, details: details, examples: [#"open -g "\#(link)""#])
    }

    private static func actionLink(_ action: String) -> URLSchemeLink {
        let link = "tooki://run/\(action)"
        let title = ShortcutActionInfo(action: action).title
        return URLSchemeLink(
            title: title,
            copyText: link,
            details: "Does the same as the \(title) shortcut.",
            examples: [#"open -g "\#(link)""#]
        )
    }

    static let shelfScript = #"""
    #!/bin/sh
    # Adds files and folders to the Tooki shelf.
    # Usage: tooki-shelf [-c] <paths…>   (-c adds copies, so the originals never move)
    mode=original
    if [ "$1" = "-c" ]; then mode=copy; shift; fi
    query=""
    for path in "$@"; do
      path=$(cd "$(dirname -- "$path")" && printf '%s/%s' "$PWD" "$(basename -- "$path")")
      query="$query&path=$(printf '%s' "$path" | perl -pe 's/([^A-Za-z0-9\/._~-])/sprintf("%%%02X", ord($1))/ge')"
    done
    open -g "tooki://shelf/add?${query#&}&mode=$mode"

    """#
}
