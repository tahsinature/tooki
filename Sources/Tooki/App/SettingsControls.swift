import SwiftUI

extension View {
    /// A pop-up picker sized to its content, for the right side of a row.
    func settingsMenuPicker() -> some View {
        pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
    }
}
