#import <AppKit/AppKit.h>
void tooki_alignment_haptic(void) {
    [NSHapticFeedbackManager.defaultPerformer performFeedbackPattern:NSHapticFeedbackPatternAlignment performanceTime:NSHapticFeedbackPerformanceTimeNow];
}

uint32_t tooki_macos_major_version(void) {
    return (uint32_t)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
}

static NSRunningApplication *launcherPreviousApp;
// Activate only the launcher, without NSApplication's application-wide raise.
void tooki_launcher_present(void *pointer) {
    NSWindow *window = (__bridge NSWindow *)pointer;
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (front.processIdentifier != NSProcessInfo.processInfo.processIdentifier)
        launcherPreviousApp = front;
    if (window.miniaturized) [window deminiaturize:nil];
    [window makeKeyAndOrderFront:nil];
    [NSRunningApplication.currentApplication activateWithOptions:NSApplicationActivateIgnoringOtherApps];
}
void tooki_launcher_dismiss(void *pointer) {
    NSWindow *window = (__bridge NSWindow *)pointer;
    // Return to the external application before ordering out the key window,
    // so AppKit does not promote Settings or another utility as the key window.
    if (window.isKeyWindow &&
        NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier == NSProcessInfo.processInfo.processIdentifier &&
        launcherPreviousApp && !launcherPreviousApp.terminated)
        [launcherPreviousApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    [window orderOut:nil];
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
