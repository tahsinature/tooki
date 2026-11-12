import Testing
@testable import TookiKit

struct IntegerSettingDraftTests {
    @Test func typingDoesNotChangeTheSavedValue() {
        var draft = IntegerSettingDraft(value: 200, range: 10...2000)
        for text in ["", "2", "20", "2000"] {
            draft.text = text
            #expect(draft.value == 200)
        }
        let committed = draft.commit()
        #expect(committed)
        #expect(draft.value == 2000)
    }

    @Test func invalidCommitKeepsThePreviousLimit() {
        for text in ["", "2", "2001", "-10", "two hundred", "12.5", "200foo"] {
            var draft = IntegerSettingDraft(value: 200, range: 10...2000)
            draft.text = text
            let committed = draft.commit()
            #expect(!committed)
            #expect(draft.value == 200)
            #expect(draft.hasError)
        }
    }

    @Test func zeroIsAnExplicitValidImageLimit() {
        var draft = IntegerSettingDraft(value: 50, range: 0...500)
        draft.text = "0"
        #expect(draft.value == 50)
        let committed = draft.commit()
        #expect(committed)
        #expect(draft.value == 0)
    }

    @Test func steppingUsesValidDraftAndStopsAtBounds() {
        var draft = IntegerSettingDraft(value: 200, range: 10...2000)
        draft.text = "1995"
        draft.adjust(by: 10)
        #expect(draft.value == 2000)
        draft.adjust(by: 10)
        #expect(draft.value == 2000)
        draft.text = "bad input"
        draft.adjust(by: -10)
        #expect(draft.value == 1990)
        #expect(!draft.hasError)
        draft.reset(to: 10)
        draft.adjust(by: -10)
        #expect(draft.value == 10)
    }

    @Test func cancellingRestoresTheCommittedValue() {
        var draft = IntegerSettingDraft(value: 200, range: 10...2000)
        draft.text = "20"
        draft.reset(to: draft.value)
        #expect(draft.text == "200")
        #expect(draft.value == 200)
    }
}
