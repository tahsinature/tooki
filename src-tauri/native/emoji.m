#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

// Match Swift Tooki: hide missing glyphs and unsupported sequences that split apart.
bool tooki_emoji_supported(const char *value) {
    @autoreleasepool {
        static CTFontRef font;
        static double singleWidth;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            font = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 20, NULL);
            NSDictionary *attributes = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font};
            CTLineRef reference = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString:@"😀" attributes:attributes]);
            singleWidth = CTLineGetTypographicBounds(reference, NULL, NULL, NULL);
            CFRelease(reference);
        });
        NSString *text = [NSString stringWithUTF8String:value];
        if (!text.length) return false;
        NSDictionary *attributes = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font};
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString:text attributes:attributes]);
        bool supported = CTLineGetTypographicBounds(line, NULL, NULL, NULL) < singleWidth * 1.5;
        for (id object in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
            CTRunRef run = (__bridge CTRunRef)object;
            CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
            if (!runFont) { supported = false; break; }
            CFStringRef name = CTFontCopyPostScriptName(runFont);
            supported = supported && CFEqual(name, CFSTR("AppleColorEmoji"));
            CFRelease(name);
        }
        CFRelease(line);
        return supported;
    }
}
