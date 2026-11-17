#import <AppKit/AppKit.h>

void tooki_utility_attach(void *nativeWindow) {
    @try {
        NSWindow *window=(__bridge NSWindow *)nativeWindow;
        window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
        window.hidesOnDeactivate=NO;
        window.allowsToolTipsWhenApplicationIsInactive=YES;
    } @catch (NSException *exception) {
        NSLog(@"Utility native attachment failed: %@", exception.reason);
    }
}

// AppKit owns interpolation; preserve the window's top edge while its content resizes.
void tooki_utility_resize(void *nativeWindow, double width, double height, bool animate) {
    NSWindow *window = (__bridge NSWindow *)nativeWindow;
    NSRect frame = window.frame;
    if (fabs(frame.size.width - width) < 0.5 && fabs(frame.size.height - height) < 0.5) return;
    frame.origin.y += frame.size.height - height;
    frame.size = NSMakeSize(width, height);
    NSScreen *screen = window.screen;
    if (screen) {
        NSRect visible = screen.visibleFrame;
        frame.origin.y = MAX(NSMinY(visible), MIN(frame.origin.y, NSMaxY(visible) - height));
    }
    BOOL motion = animate && window.visible && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    if (!motion) {
        [window setFrame:frame display:YES];
        return;
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        [[window animator] setFrame:frame display:YES];
    } completionHandler:nil];
}
