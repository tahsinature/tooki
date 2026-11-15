import Foundation
@testable import Tooki

/// Each scenario renders the production view with isolated data in both appearances.
enum VisualScenario: String, CaseIterable, Sendable {
    case rootSearch, menuBarDuplicates, clipboard, snippets, snippetForm
    case emoji, emojiFilteredActions, actionsPopup, emptyActionsPopup, filterPopup
    case shelfManager, floatingShelf, conversionSettings, conversionPreparing, conversionReview, conversionSaving

    var size: CGSize {
        switch self {
        case .floatingShelf:
            CGSize(width: ShelfMotion.width, height: 100)
        case .conversionSettings, .conversionPreparing, .conversionReview, .conversionSaving:
            CGSize(width: ShelfMotion.width, height: 570)
        default:
            CGSize(width: 750, height: 480)
        }
    }
}
