#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

static CFMachPortRef rootTap;
static CFRunLoopSourceRef rootSource;
static void (*returnToRoot)(void);
static BOOL swallowedEscape;

static CGEventRef handleRootShortcut(CGEventTapProxy proxy, CGEventType type,
                                    CGEventRef event, void *context) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        swallowedEscape = NO;
        if (rootTap) CGEventTapEnable(rootTap, true);
        return event;
    }
    if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) != 53) return event;
    if (type == kCGEventKeyUp) {
        BOOL consumed = swallowedEscape;
        swallowedEscape = NO;
        return consumed ? NULL : event;
    }
    if (!(CGEventGetFlags(event) & kCGEventFlagMaskCommand) ||
        NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier != NSProcessInfo.processInfo.processIdentifier)
        return event;
    swallowedEscape = YES;
    if (!CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat)) returnToRoot();
    return NULL;
}

// Command-Escape can be consumed before AppKit dispatches a local keyDown.
// Intercept only while Tooki is frontmost; leave other applications untouched.
void tooki_root_search_shortcut_initialize(void (*openRoot)(void)) {
    returnToRoot = openRoot;
    if (rootTap) return;
    rootTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
        kCGEventTapOptionDefault, CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp),
        handleRootShortcut, NULL);
    if (rootTap) {
        rootSource = CFMachPortCreateRunLoopSource(NULL, rootTap, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), rootSource, kCFRunLoopCommonModes);
        CGEventTapEnable(rootTap, true);
    }
}
