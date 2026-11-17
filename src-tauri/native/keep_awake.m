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

bool tooki_keep_awake_icon(unsigned char *pixels) {
    NSImage *image = [NSImage imageWithSystemSymbolName:@"cup.and.saucer.fill"
                             accessibilityDescription:@"Keep Awake"];
    if (!image) return false;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:22 pixelsHigh:22 bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
        bytesPerRow:88 bitsPerPixel:32];
    if (!bitmap) return false;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [image drawInRect:NSMakeRect(1, 1, 20, 20)];
    [NSGraphicsContext restoreGraphicsState];
    memcpy(pixels, bitmap.bitmapData, 22 * 22 * 4);
    return true;
}
