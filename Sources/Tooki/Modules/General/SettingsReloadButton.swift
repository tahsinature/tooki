import SwiftUI

/// Reports the reload result beside the button, without changing its width.
struct SettingsReloadButton: View {
    let reload: () -> Bool
    @ViewState private var succeeded = true
    @ViewState private var showsResult = false
    @ViewState private var generation = 0

    var body: some View {
        HStack(spacing: 8) {
            Button("Reload Now") {
                succeeded = reload()
                showsResult = true
                generation += 1
            }
            Label(succeeded ? "Reloaded" : "Check errors", systemImage: succeeded ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(succeeded ? Color.secondary : Color.orange)
                .frame(minWidth: 96, alignment: .leading)
                .opacity(showsResult ? 1 : 0)
                .accessibilityHidden(!showsResult)
        }
        .task(id: generation) {
            guard showsResult else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            showsResult = false
        }
    }
}
