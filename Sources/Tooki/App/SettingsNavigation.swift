import Observation

/// One history for the settings window. Filtering never changes the selected page.
@MainActor
@Observable
final class SettingsNavigation {
    var query = ""
    var page: SettingsPage = .general {
        didSet {
            guard page != oldValue, !isRestoringHistory else { return }
            backHistory.append(oldValue)
            forwardHistory = []
        }
    }
    private(set) var backHistory: [SettingsPage] = []
    private(set) var forwardHistory: [SettingsPage] = []
    @ObservationIgnored private var isRestoringHistory = false

    var filteredPages: [SettingsPage] { SettingsPage.allCases.filter { $0.matches(query) } }

    func goBack() {
        guard let previous = backHistory.popLast() else { return }
        forwardHistory.append(page)
        restore(previous)
    }

    func goForward() {
        guard let next = forwardHistory.popLast() else { return }
        backHistory.append(page)
        restore(next)
    }

    private func restore(_ page: SettingsPage) {
        isRestoringHistory = true
        self.page = page
        isRestoringHistory = false
    }
}
