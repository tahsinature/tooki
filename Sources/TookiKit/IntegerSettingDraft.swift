/// Keeps numeric edits separate from a setting until the user finishes editing.
public struct IntegerSettingDraft {
    public var text: String
    public private(set) var value: Int
    public private(set) var hasError = false
    public let range: ClosedRange<Int>

    public init(value: Int, range: ClosedRange<Int>) {
        self.value = value
        self.text = String(value)
        self.range = range
    }

    public var pendingValue: Int? {
        guard let number = Int(text), range.contains(number) else { return nil }
        return number
    }

    @discardableResult
    public mutating func commit() -> Bool {
        guard let number = pendingValue else {
            hasError = true
            return false
        }
        reset(to: number)
        return true
    }

    public mutating func reset(to number: Int) {
        value = number
        text = String(number)
        hasError = false
    }

    public mutating func adjust(by amount: Int) {
        let base = min(max(pendingValue ?? value, range.lowerBound), range.upperBound)
        let (candidate, overflow) = base.addingReportingOverflow(amount)
        let number = overflow ? (amount > 0 ? range.upperBound : range.lowerBound) : candidate
        reset(to: min(max(number, range.lowerBound), range.upperBound))
    }
}
