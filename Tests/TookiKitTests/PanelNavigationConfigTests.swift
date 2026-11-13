import Foundation
import Testing
@testable import TookiKit

struct PanelNavigationConfigTests {
    @Test func olderConfigsEnableSessionRestoration() throws {
        for json in ["{}", "{\"panelNavigation\":{}}"] {
            let config = try JSONDecoder().decode(TookiConfig.self, from: Data(json.utf8))
            #expect(config.panelNavigation.resumeLastPanel)
            #expect(config.panelNavigation.rootSearchShortcut == "cmd+escape")
        }
    }

    @Test func preferencesRoundTripIncludingDisabledShortcut() throws {
        var config = TookiConfig()
        config.panelNavigation.resumeLastPanel = false
        for shortcut in ["ctrl+shift+r", ""] {
            config.panelNavigation.rootSearchShortcut = shortcut
            let data = try JSONEncoder().encode(config)
            #expect(try JSONDecoder().decode(TookiConfig.self, from: data) == config)
        }
    }
}
