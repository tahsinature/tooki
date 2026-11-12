import Foundation

/// Starts the app, unless Tooki was run from a terminal with a command such as `Tooki shelf list`.
@main
enum TookiMain {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--snippet-worker"] {
            exit(SnippetScriptWorker.run())
        }
        if arguments.first == "shelf" {
            exit(TookiCommandLine.runShelf(Array(arguments.dropFirst())))
        }
        TookiApp.main()
    }
}

/// Commands for scripts. They only read what Tooki saved, so they work whether or not Tooki is running.
@MainActor
enum TookiCommandLine {
    private static let usage = """
        Usage: Tooki shelf list
               Prints one shelf per line: id, name and item count, separated by tabs. Most recently used first.
               Tooki shelf items <name or id>
               Prints the path of each file on that shelf, one per line.
        """

    static func runShelf(_ arguments: [String]) -> Int32 {
        let shelves = ShelfLibrary.readSaved().sorted { $0.lastUsed > $1.lastUsed }
        switch (arguments.first, arguments.count) {
        case ("list", 1):
            for shelf in shelves {
                print("\(shelf.id.uuidString)\t\(shelf.name)\t\(shelf.items.count)")
            }
            return 0
        case ("items", 2):
            let reference = arguments[1]
            let shelf = shelves.first { $0.id.uuidString.caseInsensitiveCompare(reference) == .orderedSame }
                ?? shelves.first { $0.name.caseInsensitiveCompare(reference) == .orderedSame }
            guard let shelf else {
                printError("No shelf named or with id \(reference)")
                return 1
            }
            for item in shelf.items where item.exists {
                print(item.path)
            }
            return 0
        default:
            printError(usage)
            return 64
        }
    }

    private static func printError(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
