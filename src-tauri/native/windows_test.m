#import "windows.m"
#include <assert.h>
#import "panel_dismiss.m"
static int dismissCount;
static void recordDismissal(void) { dismissCount++; }
bool tooki_preview_belongs_to_window(void *window, const char *owner) {
    return false;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSWindow *launcher = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        NSWindow *notes = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        NSWindow *settings = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        [notes orderBack:nil];
        [settings orderBack:nil];
        [launcher orderBack:nil];
        launcherPanel = launcher;
        launcherMenu = settings;
        dismissLauncher = recordDismissal;
        handleClick(launcher);
        handleClick(settings);
        assert(dismissCount == 0);
        handleClick(notes);
        handleClick(nil);
        assert(dismissCount == 2);
        tooki_window_dismiss((__bridge void *)launcher);
        handleClick(nil);
        assert(dismissCount == 2);
        assert(!launcher.visible);
        assert(notes.visible);
        assert(settings.visible);
        assert(notes.level == NSNormalWindowLevel);
        tooki_window_dismiss((__bridge void *)notes);
        assert(!notes.visible && settings.visible);
        [settings orderOut:nil];
        puts("Window dismissal preserves independent sibling windows.");
    }
    return 0;
}
