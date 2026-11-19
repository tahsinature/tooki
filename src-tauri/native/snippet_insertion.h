#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

// Ignore our replacement events so snippets never recursively expand themselves.
static const int64_t TookiSnippetEventTag = 0x544f4f4b49534e50;
extern bool tooki_clipboard_copy_expansion(NSString *text);

static BOOL AppendSnippetKey(NSMutableArray *events, CGEventSourceRef source,
                             CGKeyCode key, BOOL down, CGEventFlags flags) {
    CGEventRef event = CGEventCreateKeyboardEvent(source, key, down);
    if (!event) return NO;
    CGEventSetFlags(event, flags);
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, TookiSnippetEventTag);
    [events addObject:CFBridgingRelease(event)];
    return YES;
}

static NSArray *SnippetReplacementEvents(NSString *suffix) {
    // Configured triggers are ASCII, so one backspace removes one typed key.
    if (!suffix.length || suffix.length > 129 ||
        ![suffix canBeConvertedToEncoding:NSASCIIStringEncoding]) return nil;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (!source) return nil;
    NSMutableArray *events = [NSMutableArray new];
    BOOL valid = YES;
    for (NSUInteger i = 0; valid && i < suffix.length; i++) {
        valid = AppendSnippetKey(events, source, 51, YES, 0) &&
                AppendSnippetKey(events, source, 51, NO, 0);
    }
    valid = valid && AppendSnippetKey(events, source, 55, YES, kCGEventFlagMaskCommand) &&
            AppendSnippetKey(events, source, 9, YES, kCGEventFlagMaskCommand) &&
            AppendSnippetKey(events, source, 9, NO, kCGEventFlagMaskCommand) &&
            AppendSnippetKey(events, source, 55, NO, 0);
    CFRelease(source);
    return valid ? events : nil;
}

static NSDictionary *InsertSnippetWithKeyboard(NSString *suffix, NSString *text) {
    // Allocate the entire sequence and populate the pasteboard before deleting.
    // Paste preserves Unicode and multiline text without synthesizing Return.
    NSArray *events = SnippetReplacementEvents(suffix);
    if (!events) return SnippetFailure(@"Could not prepare text replacement. Your trigger was not changed.");
    if (!tooki_clipboard_copy_expansion(text))
        return SnippetFailure(@"Could not copy the snippet. Your trigger was not changed.");
    for (id event in events) CGEventPost(kCGHIDEventTap, (__bridge CGEventRef)event);
    return nil;
}
