/// Synthetic data only. Large-list mode exercises production containers without loading user history.
struct GallerySampleData {
    let titles: [String]

    init(arguments: [String]) {
        let examples = ["Today", "Email reply", "Project notes", "Unavailable file"]
        titles = arguments.contains("--stress-list")
            ? examples + (5...5_000).map { "Sample entry \($0)" }
            : examples
    }
}
