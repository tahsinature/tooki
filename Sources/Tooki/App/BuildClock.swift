import Foundation
import Observation

/// Refreshes native menu text even while AppKit is tracking an open menu.
@MainActor
@Observable
final class BuildClock {
    private(set) var label = BuildInfo.buildTimeLabel(relativeTo: .now)
    @ObservationIgnored private var timer: Timer?

    func start() {
        stop()
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.2
        // Default-mode timers pause while a native menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let updated = BuildInfo.buildTimeLabel(relativeTo: .now)
        if updated != label { label = updated }
    }
}
