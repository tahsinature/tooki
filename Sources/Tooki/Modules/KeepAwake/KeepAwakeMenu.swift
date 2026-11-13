import SwiftUI

/// Optional coffee icon menu, visible only while an actual power assertion is active.
struct KeepAwakeMenu: View {
    let keepAwake: KeepAwake
    let showSettings: () -> Void

    var body: some View {
        Text(keepAwake.statusText)
        if keepAwake.manualUntil != nil {
            Button("Turn Off") { keepAwake.stop() }
        } else if keepAwake.triggeringApp != nil {
            Text("Kept awake by an automatic app rule")
        }
        Divider()
        Button("15 Minutes") { keepAwake.start(minutes: 15) }
        Button("1 Hour") { keepAwake.start(minutes: 60) }
        Button("2 Hours") { keepAwake.start(minutes: 120) }
        Button("Until Turned Off") { keepAwake.start(minutes: nil) }
        Divider()
        Button("Keep Awake Settings…", action: showSettings)
    }
}
