import SwiftUI
import TookiDesignSystem

/// A separate developer application. It never starts Tooki's clipboard monitoring or reads user data.
@main
struct ComponentGalleryApp: App {
    private let sample = GallerySampleData(arguments: CommandLine.arguments)

    var body: some Scene {
        WindowGroup("Tooki Component Gallery") {
            ComponentGalleryView(titles: sample.titles)
        }
        .defaultSize(width: 1040, height: 820)
    }
}
