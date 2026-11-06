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

            Files go on the most recently used shelf. Add shelf= with a shelf's name or id to pick one, \
            or shelf=new for a new shelf. A name that doesn't exist yet makes a new shelf with that name.
            """,
            examples: [
                #"open -g "tooki://shelf/add?path=$HOME/Downloads/report.pdf""#,
                #"open -g "tooki://shelf/add?path=$HOME/Desktop/a.png&path=$HOME/Desktop/b.png&mode=copy""#,
                #"open -g "tooki://shelf/add?path=$HOME/notes.md&shelf=Work""#,
            ]
        ),
        URLSchemeLink(
            title: "New empty shelf",
            copyText: "tooki://shelf/new",
            details: "Opens a new empty shelf, ready for a drop or ⌘V.",
            examples: [#"open -g "tooki://shelf/new""#]
        ),
        simpleLink("show", "Show shelves", "Brings every shelf back where you left it, without changing what's on it."),
        simpleLink("hide", "Hide shelves", "Hides every shelf. Their items stay and come back next time they show. Empty shelves close."),
        simpleLink("toggle", "Show or hide shelves", "Hides every shelf if any is showing, otherwise shows them all (or a new one when there are none). Handy for a keyboard tool like Raycast or skhd."),
        simpleLink("clear", "Clear and close shelves", "Closes every shelf without asking. Originals stay where they are; Tooki's copies are deleted."),
        URLSchemeLink(
            title: "tooki-shelf script",
            copyText: shelfScript,
            label: "tooki-shelf",
            details: """
            A small shell script that builds the add link for you, so you don't have to encode paths. \
            Click to copy it, save it as tooki-shelf somewhere on your PATH, and make it executable \
            with chmod +x. Pass -c to add copies instead of originals, and -s to pick a shelf by \
            name or id (or -s new). tooki-shelf list prints every shelf, most recently used first. \
            Set TOOKI_BIN if Tooki isn't in /Applications.
            """,
            examples: [
                "tooki-shelf ~/Downloads/*.pdf",
                "tooki-shelf -c -s new report.pdf photos/",
                "tooki-shelf -s Work notes.md",
                "tooki-shelf list",
                "fd -e png | fzf -m | xargs tooki-shelf",
            ]
        ),
    ]

    private static func simpleLink(_ verb: String, _ title: String, _ details: String) -> URLSchemeLink {
        let link = "tooki://shelf/\(verb)"
        return URLSchemeLink(
            title: title,
            copyText: link,
            details: details + " Add ?shelf= with a name or id to act on one shelf only.",
            examples: [#"open -g "\#(link)""#, #"open -g "\#(link)?shelf=Shelf%201""#]
        )
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
    # Adds files and folders to a Tooki shelf.
    # Usage: tooki-shelf [-c] [-s <shelf>] <paths…>
    #   -c          add copies, so the originals never move
    #   -s <shelf>  a shelf name or id, or "new" (default: the most recently used shelf)
    #        tooki-shelf list   prints id, name and item count for each shelf
    tooki="${TOOKI_BIN:-/Applications/Tooki.app/Contents/MacOS/Tooki}"
    if [ "$1" = "list" ]; then exec "$tooki" shelf list; fi
    encode() { printf '%s' "$1" | perl -pe 's/([^A-Za-z0-9\/._~-])/sprintf("%%%02X", ord($1))/ge'; }
    mode=original
    shelf=""
    while getopts "cs:" option; do
      case $option in
        c) mode=copy ;;
        s) shelf="&shelf=$(encode "$OPTARG")" ;;
        *) exit 64 ;;
      esac
    done
    shift $((OPTIND - 1))
    query=""
    for path in "$@"; do
      path=$(cd "$(dirname -- "$path")" && printf '%s/%s' "$PWD" "$(basename -- "$path")")
      query="$query&path=$(encode "$path")"
    done
    open -g "tooki://shelf/add?${query#&}&mode=$mode$shelf"

    """#
}
