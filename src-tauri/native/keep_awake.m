#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

int tooki_keep_awake_create(bool display, double seconds, IOPMAssertionID *identifier) {
    return IOPMAssertionCreateWithDescription(
        display ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                : kIOPMAssertionTypePreventUserIdleSystemSleep,
        CFSTR("Tooki Keep Awake"), NULL, NULL, NULL, seconds,
        kIOPMAssertionTimeoutActionRelease, identifier);
}

bool tooki_keep_awake_active(IOPMAssertionID identifier) {
    CFDictionaryRef properties = IOPMAssertionCopyProperties(identifier);
    if (!properties) return false;
    int level = 0;
    CFNumberRef value = CFDictionaryGetValue(properties, kIOPMAssertionLevelKey);
    if (value) CFNumberGetValue(value, kCFNumberIntType, &level);
    CFRelease(properties);
    return level == kIOPMAssertionLevelOn;
}

int tooki_keep_awake_release(IOPMAssertionID identifier) {
    return IOPMAssertionRelease(identifier);
}

#import <AppKit/AppKit.h>

// Retain the SF Symbol as a native image so AppKit renders it at the screen's
// backing scale, rather than stretching a small RGBA bitmap on Retina displays.
bool tooki_set_keep_awake_icon(void *pointer) {
    NSStatusItem *item = (__bridge NSStatusItem *)pointer;
    NSStatusBarButton *button = item.button;
    NSImage *image = [NSImage imageWithSystemSymbolName:@"mug"
                             accessibilityDescription:@"Keep Awake"];
    if (!button || !image) return false;
    image = [image imageWithSymbolConfiguration:
        [NSImageSymbolConfiguration configurationWithPointSize:16
            weight:NSFontWeightRegular scale:NSImageSymbolScaleMedium]];
    image.template = YES;
    button.image = image;
    return true;
}
