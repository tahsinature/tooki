import SwiftUI

/// The answer card at the top of the launcher, after Asyar's `CalcResultCard` (large style):
/// the expression on the left, the answer on the right, each with a small label under it.
struct CalculatorCard: View {
    let calculation: SearchItem.Calculation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            side(calculation.expression, label: "Expression")
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PanelTheme.tertiaryText)
            side(calculation.result, label: calculation.resultLabel)
        }
        .frame(height: 112)
        .background(
            isSelected ? PanelTheme.selectedBackground : PanelTheme.tertiaryBackground,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PanelTheme.border))
        .contentShape(Rectangle())
    }

    private func side(_ text: String, label: String) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(PanelTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
            Text(label)
                .font(PanelTheme.labelFont)
                .foregroundStyle(PanelTheme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(PanelTheme.hoverBackground, in: Capsule())
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}
