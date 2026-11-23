#import <AppKit/AppKit.h>

// Presentation and dismissal operate on one Tooki window. AppKit owns focus
// succession; do not reactivate a remembered external app when a panel closes.
void tooki_window_present(void *pointer) {
    NSWindow *window = (__bridge NSWindow *)pointer;
    if (window.miniaturized) [window deminiaturize:nil];
    [window makeKeyAndOrderFront:nil];
    // Ordinary windows explicitly opened by the user need app activation.
    // Panel presentation uses a separate, nonactivating path.
    [NSApp activate];
}
void tooki_window_dismiss(void *pointer) {
    [(__bridge NSWindow *)pointer orderOut:nil];
}
