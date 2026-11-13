import SwiftUI
import Testing
import TookiKit
@testable import Tooki

@MainActor
@Suite struct PanelFocusRegressionTests {
    private func searchModel() -> SearchModel {
        let items = ["first", "second"].map { id in
            SearchItem(id: id, title: id, kind: "Command", group: .commands,
                       icon: .symbol("gear"), actionTitle: "Run", copy: {}, run: {})
        }
        return SearchModel(items: items, placeholder: "Search", title: "Tooki",
                           icon: .symbol("magnifyingglass"), history: LaunchHistory())
    }

    @Test func unchangedSearchCommitKeepsTheMenuAndSelection() {
        let model = searchModel()
        model.selection = 1
        model.isShowingActions = true
        model.actionSelection = 1
        let query = model.query
        model.query = query // Native TextField commits its current value on focus transfer.
        #expect(model.isShowingActions)
        #expect(model.selectedItem?.id == "second")
        #expect(model.actionSelection == 1)

        model.query = "first"
        #expect(!model.isShowingActions)
        #expect(model.selectedItem?.id == "first")
    }

    @Test func unchangedFilterAndMenuQueryKeepTheirSelections() {
        let model = searchModel()
        model.groupFilter = .commands
        model.selection = 1
        model.isShowingActions = true
        let filter = model.groupFilter
        model.groupFilter = filter
        #expect(model.isShowingActions)
        #expect(model.selection == 1)
        model.actionSelection = 1
        let query = model.menuQuery
        model.menuQuery = query
        #expect(model.actionSelection == 1)
        model.menuQuery = "copy"
        #expect(model.actionSelection == 0)
        #expect(model.selectedMenuAction?.id == "copy")
    }

    @Test func sharedMenuIgnoresFocusCommitsButExplicitNavigationStillResets() {
        let model = searchModel()
        let menu = ActionsMenu<SearchAction>()
        menu.rootActions = { model.menuActions }
        menu.open()
        menu.selection = 1
        let query = menu.query
        menu.query = query
        #expect(menu.selection == 1)
        menu.showSubmenu(title: "Child", actions: model.menuActions, parentID: "copy")
        #expect(menu.selection == 0)
        #expect(menu.dismiss())
        #expect(menu.selectedAction?.id == "copy")
        menu.close()
        menu.open()
        #expect(menu.isShowing)
        #expect(menu.selection == 0)
    }

    @Test func sharedBindingDropsFocusCommitsAndPreservesEditTransactions() {
        var text = "existing query"
        var writes = 0
        var receivedTransaction = false
        let binding = Binding<String>(get: { text }, set: { value, transaction in
            text = value
            writes += 1
            receivedTransaction = transaction.disablesAnimations
        }).ignoringUnchangedValues()

        binding.wrappedValue = "existing query"
        #expect(writes == 0)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        binding.transaction(transaction).wrappedValue = "edited query"
        #expect(text == "edited query")
        #expect(writes == 1)
        #expect(receivedTransaction)
    }
}
