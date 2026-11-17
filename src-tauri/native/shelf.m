#import <AppKit/AppKit.h>
// Same content-drag test as Swift ShelfDragWatcher. No event suppression or key logging.
static id globalMonitor, localMonitor;
static NSInteger dragChangeCount;
static BOOL startedHere, fired;
static void (*shelfCallback)(uint8_t);
static void handleShelfEvent(NSEvent *event, BOOL local) {
    if (event.type == NSEventTypeFlagsChanged && shelfCallback) shelfCallback((event.modifierFlags & NSEventModifierFlagOption) ? 3 : 4);
    if (event.type == NSEventTypeLeftMouseDown) {
        dragChangeCount = [NSPasteboard pasteboardWithName:NSPasteboardNameDrag].changeCount;
        startedHere = local;
        fired = NO;
    } else if (event.type == NSEventTypeLeftMouseUp) {
        if (fired && shelfCallback) shelfCallback(2);
        fired = NO;
    } else if (!fired && !startedHere &&
               (event.modifierFlags & NSEventModifierFlagShift) &&
               (NSEvent.pressedMouseButtons & 1) &&
               [NSPasteboard pasteboardWithName:NSPasteboardNameDrag].changeCount != dragChangeCount) {
        fired = YES;
        if (shelfCallback) shelfCallback(1);
    }

}
bool tooki_shelf_watch(bool enabled, void (*callback)(uint8_t)) {
    NSCAssert(NSThread.isMainThread, @"Shelf monitoring must run on the main thread");
    if (!enabled) {
        if (globalMonitor) [NSEvent removeMonitor:globalMonitor];
        if (localMonitor) [NSEvent removeMonitor:localMonitor];
        globalMonitor = nil; localMonitor = nil;
        if (fired && shelfCallback) shelfCallback(2);
        fired = NO; shelfCallback = NULL;
        return true;
    }
    shelfCallback = callback;
    if (globalMonitor) return true;
    startedHere = YES; fired = NO;
    NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskLeftMouseDragged |
                       NSEventMaskLeftMouseUp | NSEventMaskFlagsChanged;
    globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mask handler:^(NSEvent *event) {
        handleShelfEvent(event, NO);
    }];
    localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
        handleShelfEvent(event, YES);
        return event;
    }];
    return globalMonitor != nil && localMonitor != nil;
}
