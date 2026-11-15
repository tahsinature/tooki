/// Portable launcher metadata, without AppKit images or executable closures.
public struct SearchEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let keyword: String?
    public let kind: String
    public let group: SearchGroup
    public let searchText: String
    public let actions: [SearchActionMetadata]

    public init(id: String, title: String, subtitle: String? = nil, keyword: String? = nil,
                kind: String = "Command", group: SearchGroup = .commands, searchText: String = "",
                actions: [SearchActionMetadata] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keyword = keyword
        self.kind = kind
        self.group = group
        self.searchText = searchText
        self.actions = actions
    }
}
