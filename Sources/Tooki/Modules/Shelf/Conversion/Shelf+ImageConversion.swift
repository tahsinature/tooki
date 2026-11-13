import Foundation
import TookiKit

extension Shelf {
    func beginImageConversion(_ candidates: [ShelfItem]) {
        guard imageConversion == nil, canConvertImages(candidates) else { return }
        let model = ShelfImageConversionModel(items: candidates, shelf: self)
        imageConversion = model
        disarm()
        isExpanded = true
        isShowingConversion = true
    }

    func endImageConversion(_ model: ShelfImageConversionModel) {
        guard imageConversion?.id == model.id else { return }
        isShowingConversion = false
        // Keep the outgoing page alive until its slide finishes.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(ShelfMotion.duration))
            guard let self, imageConversion?.id == model.id, !isShowingConversion else { return }
            imageConversion = nil
            if !model.previousWasExpanded { isExpanded = false }
        }
    }

    /// Validate the entire selection, never just its image subset. A folder, PDF, text,
    /// link, missing file or unfinished copy suppresses the menu action.
    func canConvertImages(_ candidates: [ShelfItem]) -> Bool {
        guard !candidates.isEmpty, candidates.allSatisfy({ item in
            !item.isLink && item.text == nil && !copyingIDs.contains(item.id) && items.contains(item)
        }) else { return false }
        return ImageConverter.supports(candidates.map(\.url))
    }
}
