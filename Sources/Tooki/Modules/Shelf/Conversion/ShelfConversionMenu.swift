import SwiftUI

/// Keeps the format and size controls the same width while retaining native menus.
struct ShelfConversionMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [Value]
    let label: (Value) -> String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(choices, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Text(label(selection)).font(.system(size: 12))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 126, height: 26)
        .padding(.horizontal, 10)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(PanelTheme.popupDivider))
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}
