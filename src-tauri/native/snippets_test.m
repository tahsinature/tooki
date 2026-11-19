#import "snippets.m"
#define CHECK(test) if (!(test)) { fprintf(stderr,"Failed at line %d: %s\n",__LINE__,#test); return 1; }

pid_t tooki_clipboard_target_pid(void) { return 0; }
// Tests never write the real clipboard or post keyboard events.
bool tooki_clipboard_copy_expansion(NSString *text) { return false; }

int main(void) {
    @autoreleasepool {
        NSArray *events = SnippetReplacementEvents(@"$today ");
        CHECK(events.count == 18); // Seven backspaces and Command-V down/up.
        for (NSUInteger i = 0; i < events.count; i++) {
            CGEventRef event = (__bridge CGEventRef)events[i];
            CHECK(CGEventGetIntegerValueField(event, kCGEventSourceUserData) == TookiSnippetEventTag);
            int code = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
            CHECK(code != 36 && code != 76); // Never Return or keypad Enter.
            if (i < 14) {
                CHECK(code == 51);
                CHECK(CGEventGetFlags(event) == 0);
                CHECK(CGEventGetType(event) == (i % 2 ? kCGEventKeyUp : kCGEventKeyDown));
            }
        }
        CHECK(CGEventGetIntegerValueField((__bridge CGEventRef)events[15], kCGKeyboardEventKeycode) == 9);
        CHECK(CGEventGetFlags((__bridge CGEventRef)events[15]) == kCGEventFlagMaskCommand);
        CHECK(CGEventGetFlags((__bridge CGEventRef)events.lastObject) == 0);
        CHECK(!SnippetReplacementEvents(@""));
        CHECK(!SnippetReplacementEvents(@"😀"));
        CHECK(!SnippetReplacementEvents([@"a" stringByPaddingToLength:130 withString:@"a" startingAtIndex:0]));
        CHECK(InsertSnippetWithKeyboard(@"$today ", @"2026-11-17 ")[@"error"] != nil);

        typed = [@"$today" mutableCopy];
        generation = 42;
        CGEventRef synthetic = (__bridge CGEventRef)events[0];
        CHECK(ObserveTyping(NULL, kCGEventKeyDown, synthetic, NULL) == synthetic);
        CHECK([typed isEqual:@"$today"] && generation == 42);
        ObserveTyping(NULL, kCGEventTapDisabledByTimeout, NULL, NULL);
        CHECK(!typed.length && generation == 43);
        StopExpansion();
        CHECK(!typed.length && generation == 44);
        puts("Snippet fallback sequence, clipboard failure and recursive-event guards passed. No keyboard events were posted.");
    }
    return 0;
}
