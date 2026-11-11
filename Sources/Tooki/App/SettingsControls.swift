import SwiftUI

/// A value label beside a stepper, for counts like "500 items".
struct SettingsStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let valueLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Text(valueLabel)
                .foregroundStyle(SettingsTheme.secondaryText)
                .monospacedDigit()
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

extension View {
    /// A pop-up picker sized to its content, for the right side of a row.
    func settingsMenuPicker() -> some View {
        pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
    }
}
