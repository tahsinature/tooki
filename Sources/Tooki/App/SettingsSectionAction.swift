/// An optional action beside a settings section's heading.
struct SettingsSectionAction {
    let title: String
    let symbol: String
    let run: () -> Void
}
