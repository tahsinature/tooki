#import "toast.m"
#define CHECK(test) if (!(test)) { fprintf(stderr, "Failed at line %d: %s\n", __LINE__, #test); return 1; }
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSRect display = NSMakeRect(-1440, 24, 1440, 850);
        TookiToastPanel *success = makeToast(@"Trash emptied", NO, display);
        CHECK(!success.canBecomeKeyWindow && !success.canBecomeMainWindow);
        CHECK(success.ignoresMouseEvents && !success.hidesOnDeactivate);
        CHECK(success.styleMask & NSWindowStyleMaskNonactivatingPanel);
        CHECK(NSContainsRect(display, success.frame));
        CHECK(NSMidX(display) == NSMidX(success.frame));
        CHECK(!success.visible); // Constructing feedback does not display or focus it.
        CHECK([success.contentView isKindOfClass:NSVisualEffectView.class]);
        TookiToastPanel *failure = makeToast([@"A long failure message. " stringByPaddingToLength:600 withString:@"More detail. " startingAtIndex:0], YES, display);
        CHECK(failure.frame.size.height <= 82);
        CHECK(NSContainsRect(display, failure.frame));
        NSRect small = NSMakeRect(0, 0, 300, 200);
        CHECK(NSContainsRect(small, makeToast(@"Done", NO, small).frame));
        CHECK(!NSApp.keyWindow && !NSApp.mainWindow);
        puts("Native toast layout and nonactivation checks passed.");
    }
    return 0;
}
