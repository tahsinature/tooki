import SwiftUI

struct MenuBarLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: BuildInfo.isRelease
            ? MenuBarIcon.image
            : MenuBarIcon.developmentImage(darkAppearance: colorScheme == .dark))
            .accessibilityLabel(BuildInfo.appName)
    }
}
