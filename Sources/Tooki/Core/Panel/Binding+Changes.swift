import SwiftUI

extension Binding where Value: Equatable & Sendable {
    /// Native text fields can commit unchanged text when focus moves into a popup.
    /// Keep those commits from triggering model side effects, preserving real edit transactions.
    func ignoringUnchangedValues() -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { value, transaction in
                guard value != wrappedValue else { return }
                self.transaction(transaction).wrappedValue = value
            }
        )
    }
}
