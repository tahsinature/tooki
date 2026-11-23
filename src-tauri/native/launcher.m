#import <AppKit/AppKit.h>
void tooki_alignment_haptic(void) {
    [NSHapticFeedbackManager.defaultPerformer performFeedbackPattern:NSHapticFeedbackPatternAlignment performanceTime:NSHapticFeedbackPerformanceTimeNow];
}

uint32_t tooki_macos_major_version(void) {
    return (uint32_t)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
}

// Resize in one main-thread frame update, preserving the user's top-left anchor.
void tooki_launcher_resize(void *pointer, double width, double height) {
    NSWindow *window = (__bridge NSWindow *)pointer;
    NSRect previous = window.frame;
    NSRect next = [window frameRectForContentRect:NSMakeRect(0, 0, width, height)];
    next.origin.x = previous.origin.x;
    next.origin.y = NSMaxY(previous) - next.size.height;
    [window setFrame:next display:YES animate:NO];
}
