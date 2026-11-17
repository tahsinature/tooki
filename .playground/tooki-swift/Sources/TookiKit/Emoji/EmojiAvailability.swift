import CoreText
import Foundation

/// Keeps only emoji the installed Apple Color Emoji font can draw, so newer Unicode emoji
/// that this macOS doesn't support yet are hidden instead of showing as empty boxes.
enum EmojiAvailability {
    static func drawable(_ emoji: [Emoji]) -> [Emoji] {
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
        let singleWidth = width(of: line("😀", font: font))
        return emoji.filter { canDraw($0.character, font: font, singleWidth: singleWidth) }
    }

    private static func canDraw(_ emoji: String, font: CTFont, singleWidth: Double) -> Bool {
        let line = line(emoji, font: font)
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        let usesOnlyEmojiFont = runs.allSatisfy { run in
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let runFont = attributes[kCTFontAttributeName] else { return false }
            return CTFontCopyPostScriptName(runFont as! CTFont) as String == "AppleColorEmoji"
        }
        // An unsupported sequence falls apart into several side-by-side emoji.
        return usesOnlyEmojiFont && width(of: line) < singleWidth * 1.5
    }

    private static func line(_ text: String, font: CTFont) -> CTLine {
        let key = NSAttributedString.Key(kCTFontAttributeName as String)
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [key: font]))
    }

    private static func width(of line: CTLine) -> Double {
        CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}
