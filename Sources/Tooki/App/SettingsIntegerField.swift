import SwiftUI
import TookiKit

/// Direct numeric entry with explicit commit, so typing cannot prematurely trim history.
struct SettingsIntegerField: View {
    let title: String
    @Binding var value: Int
    let step: Int
    let unit: String
    var zeroHint: String? = nil

    @ViewState private var draft: IntegerSettingDraft
    @FocusState private var isFocused: Bool
    @ViewState private var isHovered = false

    init(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String, zeroHint: String? = nil) {
        self.title = title
        self._value = value
        self.step = step
        self.unit = unit
        self.zeroHint = zeroHint
        self._draft = ViewState(wrappedValue: IntegerSettingDraft(value: value.wrappedValue, range: range))
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 8) {
                TextField("", text: $draft.text)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(SettingsTheme.controlFont.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onKeyPress(.upArrow, phases: [.down, .repeat]) { _ in
                        adjust(by: step)
                        return .handled
                    }
                    .onKeyPress(.downArrow, phases: [.down, .repeat]) { _ in
                        adjust(by: -step)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        draft.reset(to: value)
                        isFocused = false
                        return .handled
                    }
                    .accessibilityLabel(title)
                    .accessibilityHint("Enter a whole number from \(draft.range.lowerBound) to \(draft.range.upperBound)")
                Text(unit)
                    .font(SettingsTheme.controlFont)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Divider().frame(height: 16)
                VStack(spacing: 0) {
                    SettingsStepButton(title: "Increase \(title)", symbol: "chevron.up") { adjust(by: step) }
                        .disabled(currentValue >= draft.range.upperBound)
                    Divider().padding(.horizontal, 5)
                    SettingsStepButton(title: "Decrease \(title)", symbol: "chevron.down") { adjust(by: -step) }
                        .disabled(currentValue <= draft.range.lowerBound)
                }
                .frame(width: 22, height: 24)
            }
            .padding(.leading, 9)
            .padding(.trailing, 3)
            .frame(width: 148, height: 28)
            .background(SettingsTheme.searchBackground, in: RoundedRectangle(cornerRadius: SettingsTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsTheme.controlRadius)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            .background {
                SettingsNumberFocusArea(isFocused: isFocused) {
                    isFocused = false
                }
                .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            Text(hasError ? "Enter \(rangeLabel)" : rangeLabel)
                .font(SettingsTheme.metadataFont)
                .foregroundStyle(hasError ? Color.red : Color.secondary)
                .accessibilityLabel(hasError ? "Enter a whole number from \(rangeLabel)" : "Allowed range: \(rangeLabel)")
        }
        .fixedSize()
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: value) { _, newValue in
            if !isFocused { draft.reset(to: newValue) }
        }
        .onDisappear(perform: commit)
    }

    private var currentValue: Int { draft.pendingValue ?? draft.value }
    private var hasError: Bool { draft.hasError && draft.pendingValue == nil }

    private var rangeLabel: String {
        let limits = "\(draft.range.lowerBound.formatted())–\(draft.range.upperBound.formatted())"
        return zeroHint.map { "\(limits) · \($0)" } ?? limits
    }

    private var borderColor: Color {
        if hasError { return .red.opacity(0.75) }
        if isFocused { return .accentColor }
        return SettingsTheme.cardBorder.opacity(isHovered ? 1 : 0.7)
    }

    private func commit() {
        if draft.commit(), value != draft.value { value = draft.value }
    }

    private func adjust(by amount: Int) {
        draft.adjust(by: amount)
        value = draft.value
    }
}
