#import <AppKit/AppKit.h>

extern bool tooki_preview_belongs_to_window(void *window, const char *owner);
static __weak NSWindow *launcherPanel;
static __weak NSWindow *launcherMenu;
static __weak NSWindow *filterPanel;
static id localClicks;
static id externalClicks;
static void (*dismissLauncher)(void);

static BOOL isLauncherClick(NSWindow *window) {
    if (!window) return NO;
    if (window == launcherPanel || window == launcherMenu || window == filterPanel) return YES;
    if (tooki_preview_belongs_to_window((__bridge void *)window, "main")) return YES;
    return window.parentWindow ? isLauncherClick(window.parentWindow) : NO;
}
static void handleClick(NSWindow *window) {
    if (launcherPanel.visible && !isLauncherClick(window) && dismissLauncher) dismissLauncher();
}

// Nonactivating panels leave the external app active, so app-deactivation
// notifications cannot implement outside-click dismissal. Observe clicks without
// consuming them; the clicked app or Tooki workspace receives the original event.
void tooki_panel_dismiss_initialize(void *launcher, void *menu, void *filter, void (*callback)(void)) {
    launcherPanel = (__bridge NSWindow *)launcher;
    launcherMenu = (__bridge NSWindow *)menu;
    filterPanel = (__bridge NSWindow *)filter;
    dismissLauncher = callback;
    if (localClicks) return;
    NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown;
    localClicks = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
        handleClick(event.window);
        return event;
    }];
    externalClicks = [NSEvent addGlobalMonitorForEventsMatchingMask:mask handler:^(NSEvent *event) {
        (void)event;
        handleClick(nil);
    }];
}
