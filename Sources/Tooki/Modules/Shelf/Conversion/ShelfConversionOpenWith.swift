import AppKit
import SwiftUI

struct ShelfConversionOpenWith: View {
    let result: ShelfConversionResult
    let model: ShelfImageConversionModel

    var body: some View {
        Menu("Open With…") {
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: result.preview.url)
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            ForEach(apps, id: \.self) { app in
                Button(FileManager.default.displayName(atPath: app.path).replacing(/\.app$/, with: "")) {
                    model.markOpened([result.id])
                    NSWorkspace.shared.open([result.preview.url], withApplicationAt: app,
                                            configuration: NSWorkspace.OpenConfiguration()) { _, error in
                        if let error { Task { @MainActor in NSAlert(error: error).runModal() } }
                    }
                }
            }
            if apps.isEmpty { Text("No compatible apps found") }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Open the temporary converted file. The source stays unchanged.")
    }
}
