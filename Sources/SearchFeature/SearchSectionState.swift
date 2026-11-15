public struct SearchSectionState: Equatable, Identifiable, Sendable {
    public let title: String
    public let items: [SearchEntry]
    public var id: String { title }

    public init(title: String, items: [SearchEntry]) {
        self.title = title
        self.items = items
    }
}
