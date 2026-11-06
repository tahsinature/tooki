import Foundation

/// Starts the app, unless Tooki was run from a terminal with a command such as `Tooki shelf list`.
@main
enum TookiMain {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "shelf" {
            exit(TookiCommandLine.runShelf(Array(arguments.dropFirst())))
        }
        TookiApp.main()
    }
}

/// Commands for scripts. They only read what Tooki saved, so they work whether or not Tooki is running.
@MainActor
enum TookiCommandLine {
    static func runShelf(_ arguments: [String]) -> Int32 {
        guard arguments.first == "list" else {
            printError("Usage: Tooki shelf list\nPrints one shelf per line: id, name and item count, separated by tabs. Most recently used first.")
            return 64
        }
        let shelves = ShelfLibrary.readSaved()
            .sorted { $0.lastUsed > $1.lastUsed }
        for shelf in shelves {
            print("\(shelf.id.uuidString)\t\(shelf.name)\t\(shelf.items.count)")
        }
        return 0
    }

    private static func printError(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
