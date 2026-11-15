import ComposableArchitecture
import EmojiFeature
import Observation
import TookiDesignSystem
import TookiKit

/// Bridges portable emoji browsing state to the native panel and paste services.
@MainActor
@Observable
final class EmojiPanelModel {
    typealias Section = EmojiFeature.Section
    static let columns = 10
    let store: StoreOf<EmojiFeature>
    let navigation = PanelKeyboardNavigation()

    init(recentCharacters: [String]) {
        store = Store(initialState: EmojiFeature.State(recentCharacters: recentCharacters)) { EmojiFeature() }
    }

    var query: String {
        get { store.query }
        set { store.send(.queryChanged(newValue)) }
    }
    var sections: [Section] { store.sections }
    var results: [Emoji] { store.results }
    var selected: Emoji? { store.selected }
    var selection: Int {
        get { store.selection }
        set { store.send(.selectionChanged(newValue)) }
    }
    var isShowingActions: Bool {
        get { store.isShowingActions }
        set { store.send(.actionsPresented(newValue)) }
    }
    var actionQuery: String {
        get { store.actionQuery }
        set { store.send(.actionQueryChanged(newValue)) }
    }
    var visibleActions: [EmojiAction] { store.visibleActions }
    var selectedAction: EmojiAction? { store.selectedAction }
    var actionSelection: Int {
        get { store.actionSelection }
        set { store.send(.actionSelectionChanged(newValue)) }
    }

    func refresh(recentCharacters: [String]) { store.send(.recentChanged(recentCharacters)) }
    func moveSelection(by offset: Int) { store.send(.moveSelection(offset)) }
    func moveActionSelection(by offset: Int) { store.send(.moveActionSelection(offset)) }
    func resetPosition() {
        store.send(.resetPosition)
        navigation.moved(in: .results)
    }
}
